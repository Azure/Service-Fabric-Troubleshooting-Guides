# Web Role Migration Example: Azure Cloud Services to Service Fabric

This document provides a comprehensive example of migrating an ASP.NET Web Role from Azure Cloud Services to a Service Fabric Stateless Service. It includes detailed code examples, configuration changes, and best practices.

## Table of Contents
1. [Project Structure Migration](#project-structure-migration)
2. [Project File Updates](#project-file-updates)
3. [Service Implementation](#service-implementation)
4. [Startup Configuration](#startup-configuration)
5. [Configuration Migration](#configuration-migration)
6. [Middleware Migration](#middleware-migration)
7. [Dependency Injection Setup](#dependency-injection-setup)
8. [Health Monitoring](#health-monitoring)
9. [Deployment Configuration](#deployment-configuration)
10. [Key Migration Considerations](#key-migration-considerations)

## Project Structure Migration

First, create the new Service Fabric application and service:

```powershell
# Create new Service Fabric Application
New-ServiceFabricApplication -ApplicationName "fabric:/MyWebApp" -ApplicationTypeName "MyWebAppType" -ApplicationTypeVersion "1.0.0"

# Create new Stateless Service
New-ServiceFabricService -ApplicationName "fabric:/MyWebApp" -ServiceName "fabric:/MyWebApp/WebService" -ServiceTypeName "WebServiceType" -Stateless -PartitionSchemeSingleton -InstanceCount 1
```

## Project File Updates

### Original Cloud Services Web Role (.csproj)
```xml
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <ProjectGuid>{YOUR-GUID}</ProjectGuid>
    <OutputType>Library</OutputType>
    <AppDesignerFolder>Properties</AppDesignerFolder>
    <RootNamespace>MyWebRole</RootNamespace>
    <AssemblyName>MyWebRole</AssemblyName>
    <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
    <UseIISExpress>true</UseIISExpress>
    <Use64BitIISExpress />
  </PropertyGroup>
</Project>
```

### New Service Fabric Stateless Service (.csproj)
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <AzureFunctionsJobHost>true</AzureFunctionsJobHost>
    <RootNamespace>MyWebService</RootNamespace>
    <AssemblyName>MyWebService</AssemblyName>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.ServiceFabric.Services.AspNetCore" Version="6.0.0" />
    <PackageReference Include="Microsoft.ServiceFabric.Services" Version="6.0.0" />
  </ItemGroup>
</Project>
```

## Service Implementation

### Original Web Role
```csharp
public class WebRole : RoleEntryPoint
{
    public override bool OnStart()
    {
        // Web Role startup code
        return base.OnStart();
    }
}
```

### New Service Fabric Stateless Service
```csharp
public class WebService : StatelessService
{
    private readonly ILogger<WebService> _logger;
    private readonly IConfiguration _configuration;

    public WebService(
        StatelessServiceContext context,
        ILogger<WebService> logger,
        IConfiguration configuration)
        : base(context)
    {
        _logger = logger;
        _configuration = configuration;
    }

    protected override IEnumerable<ServiceInstanceListener> CreateServiceInstanceListeners()
    {
        return new ServiceInstanceListener[]
        {
            new ServiceInstanceListener(serviceContext =>
                new KestrelListener(serviceContext, "ServiceEndpoint", (url, listener) =>
                {
                    return new WebHostBuilder()
                        .UseKestrel()
                        .ConfigureServices(
                            services => services
                                .AddSingleton<StatelessServiceContext>(serviceContext)
                                .AddSingleton<ILoggerFactory>(new LoggerFactory())
                                .AddSingleton(typeof(ILogger<>), typeof(Logger<>))
                                .AddMvc())
                        .UseContentRoot(Directory.GetCurrentDirectory())
                        .UseStartup<Startup>()
                        .UseUrls(url)
                        .Build();
                }))
        };
    }
}
```

## Startup Configuration

```csharp
public class Startup
{
    public Startup(IConfiguration configuration)
    {
        Configuration = configuration;
    }

    public IConfiguration Configuration { get; }

    public void ConfigureServices(IServiceCollection services)
    {
        // Add services to the container
        services.AddControllers();
        services.AddSwaggerGen();
        
        // Add custom services
        services.AddSingleton<IMyService, MyService>();
        
        // Configure options
        services.Configure<MyOptions>(Configuration.GetSection("MySettings"));
    }

    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        app.UseHttpsRedirection();
        app.UseRouting();
        app.UseAuthorization();
        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllers();
        });
    }
}
```

## Configuration Migration

### Original Web Role Settings
```xml
<ConfigurationSettings>
    <Setting name="ConnectionString" value="DefaultConnection" />
    <Setting name="ApiKey" value="DefaultApiKey" />
</ConfigurationSettings>
```

### New Service Fabric Settings.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<Settings xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
          xmlns="http://schemas.microsoft.com/2011/01/fabric">
  <Section Name="MySettings">
    <Parameter Name="ConnectionString" Value="" />
    <Parameter Name="ApiKey" Value="" />
  </Section>
</Settings>
```

### ApplicationManifest.xml Override
```xml
<ApplicationManifest ...>
  <Parameters>
    <Parameter Name="WebService_ConnectionString" DefaultValue="" />
    <Parameter Name="WebService_ApiKey" DefaultValue="" />
  </Parameters>
  
  <ServiceManifestImport>
    <ServiceManifestRef ServiceManifestName="WebServicePkg" ServiceManifestVersion="1.0.0" />
    <ConfigOverrides>
      <ConfigOverride Name="Config">
        <Settings>
          <Section Name="MySettings">
            <Parameter Name="ConnectionString" Value="[WebService_ConnectionString]" />
            <Parameter Name="ApiKey" Value="[WebService_ApiKey]" />
          </Section>
        </Settings>
      </ConfigOverride>
    </ConfigOverrides>
  </ServiceManifestImport>
</ApplicationManifest>
```

## Middleware Migration

### Original Web Role Global.asax.cs
```csharp
public class WebApiApplication : System.Web.HttpApplication
{
    protected void Application_Start()
    {
        GlobalConfiguration.Configure(WebApiConfig.Register);
        FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
        RouteConfig.RegisterRoutes(RouteTable.Routes);
        BundleConfig.RegisterBundles(BundleTable.Bundles);
    }
}
```

### New Service Fabric Program.cs
```csharp
public class Program
{
    public static void Main(string[] args)
    {
        CreateHostBuilder(args).Build().Run();
    }

    public static IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args)
            .ConfigureWebHostDefaults(webBuilder =>
            {
                webBuilder.UseStartup<Startup>();
            });
}
```

## Dependency Injection Setup

### Original Web Role Service Registration
```csharp
public static class UnityConfig
{
    public static void RegisterComponents()
    {
        var container = new UnityContainer();
        container.RegisterType<IMyService, MyService>();
        GlobalConfiguration.Configuration.DependencyResolver = new UnityResolver(container);
    }
}
```

### New Service Fabric Service Registration
```csharp
public void ConfigureServices(IServiceCollection services)
{
    // Register services
    services.AddScoped<IMyService, MyService>();
    
    // Register options
    services.Configure<MyOptions>(Configuration.GetSection("MySettings"));
    
    // Register HTTP clients
    services.AddHttpClient<IMyHttpClient, MyHttpClient>();
}
```

## Health Monitoring

```csharp
public class WebService : StatelessService
{
    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Register health check
        var healthCheck = new HealthCheck(
            "WebServiceHealth",
            TimeSpan.FromSeconds(30),
            TimeSpan.FromSeconds(10),
            TimeSpan.FromSeconds(5));

        healthCheck.Start();

        while (!cancellationToken.IsCancellationRequested)
        {
            // Report health
            var healthInfo = new HealthInformation("WebService", "HealthCheck", HealthState.Ok);
            Partition.ReportInstanceHealth(healthInfo);

            await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
        }
    }
}
```

## Deployment Configuration

```powershell
# Deploy the application
$publishProfile = "Local.1Node.xml"
$appPackagePath = "pkg\Debug"

Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $appPackagePath -ImageStoreConnectionString "file:C:\SfDevCluster\Data\ImageStoreShare" -ApplicationPackagePathInImageStore "MyWebApp"

Register-ServiceFabricApplicationType -ApplicationPathInImageStore "MyWebApp"

New-ServiceFabricApplication -ApplicationName "fabric:/MyWebApp" -ApplicationTypeName "MyWebAppType" -ApplicationTypeVersion "1.0.0"
```

## Key Migration Considerations

### 1. Session State Management
- Replace ASP.NET Session State with Service Fabric stateful services
- Consider using distributed caching solutions
- Implement sticky sessions if required

### 2. Authentication/Authorization
- Migrate authentication middleware
- Update authorization policies
- Configure identity providers

### 3. Logging and Diagnostics
- Implement structured logging
- Configure application insights
- Set up health monitoring

### 4. Performance Optimization
- Configure connection pooling
- Implement caching strategies
- Optimize resource usage

## Additional Resources

- [Service Fabric Documentation](https://docs.microsoft.com/azure/service-fabric)
- [ASP.NET Core in Service Fabric](https://docs.microsoft.com/azure/service-fabric/service-fabric-reliable-services-communication-aspnetcore)
- [Service Fabric Samples](https://github.com/Azure-Samples/service-fabric-dotnet-getting-started) 