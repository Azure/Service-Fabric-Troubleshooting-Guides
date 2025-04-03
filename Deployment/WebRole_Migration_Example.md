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
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsServiceFabricServiceProject>True</IsServiceFabricServiceProject>
    <ServerGarbageCollection>True</ServerGarbageCollection>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>True</SelfContained>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.ServiceFabric.AspNetCore.Kestrel" Version="7.0.1949" />
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
internal sealed class WebService : StatelessService
{
    public WebService(StatelessServiceContext context)
        : base(context)
    { }

    /// <summary>
    /// Optional override to create listeners (like tcp, http) for this service instance.
    /// </summary>
    /// <returns>The collection of listeners.</returns>
    protected override IEnumerable<ServiceInstanceListener> CreateServiceInstanceListeners()
    {
        return new ServiceInstanceListener[]
        {
            new ServiceInstanceListener(serviceContext =>
                new KestrelCommunicationListener(serviceContext, "ServiceEndpoint", (url, listener) =>
                {
                    ServiceEventSource.Current.ServiceMessage(serviceContext, $"Starting Kestrel on {url}");

                    var builder = WebApplication.CreateBuilder();

                    builder.Services.AddSingleton<StatelessServiceContext>(serviceContext);
                    builder.WebHost
                                .UseKestrel()
                                .UseContentRoot(Directory.GetCurrentDirectory())
                                .UseServiceFabricIntegration(listener, ServiceFabricIntegrationOptions.None)
                                .UseStartup<Startup>()
                                .UseUrls(url);
                    builder.Services.AddControllersWithViews();
                    var app = builder.Build();
                    if (!app.Environment.IsDevelopment())
                    {
                    app.UseExceptionHandler("/Home/Error");
                    }
                    app.UseStaticFiles();
                    app.UseRouting();
                    app.UseAuthorization();
                    app.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
                    
                    return app;

                }))
        };
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
internal static class Program
{
    /// <summary>
    /// This is the entry point of the service host process.
    /// </summary>
    private static void Main()
    {
        try
        {
            // The ServiceManifest.XML file defines one or more service type names.
            // Registering a service maps a service type name to a .NET type.
            // When Service Fabric creates an instance of this service type,
            // an instance of the class is created in this host process.

            ServiceRuntime.RegisterServiceAsync("WebServiceType",
                context => new WebService(context)).GetAwaiter().GetResult();

            ServiceEventSource.Current.ServiceTypeRegistered(Process.GetCurrentProcess().Id, typeof(WebService).Name);

            // Prevents this host process from terminating so services keeps running. 
            Thread.Sleep(Timeout.Infinite);
        }
        catch (Exception e)
        {
            ServiceEventSource.Current.ServiceHostInitializationFailed(e.ToString());
            throw;
        }
    }
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