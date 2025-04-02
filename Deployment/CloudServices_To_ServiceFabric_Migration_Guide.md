# Comprehensive Guide: Migrating from Azure Cloud Services to Service Fabric

This guide provides detailed steps and best practices for migrating applications from Azure Cloud Services to Azure Service Fabric. Throughout this guide, we recommend using [Service Fabric Managed Clusters](https://learn.microsoft.com/en-us/azure/service-fabric/overview-managed-cluster) as they provide simplified cluster management, enhanced security, and automated patching.

## Table of Contents
1. [Pre-Migration Assessment](#pre-migration-assessment)
2. [Architecture Planning](#architecture-planning)
3. [Migration Strategy](#migration-strategy)
4. [Step-by-Step Migration Process](#step-by-step-migration-process)
5. [Testing and Validation](#testing-and-validation)
6. [Post-Migration Considerations](#post-migration-considerations)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Common Migration Scenarios](#common-migration-scenarios)
9. [Additional Resources](#additional-resources)

## Pre-Migration Assessment

Before migrating from Azure Cloud Services to Service Fabric, conduct a thorough assessment:

### 1. Application Inventory
- Document all Web and Worker roles
- Identify dependencies and integration points
- Map storage requirements (local disk, Azure Storage, etc.)
- Document scaling requirements

### 2. Traffic Patterns and Scaling Requirements
- Analyze current traffic patterns
- Document scaling triggers and rules
- Assess auto-scaling requirements

### 3. State Management
- Identify stateful components
- Document data persistence mechanisms
- Assess cache dependencies

### 4. Identify Application Constraints
- Startup dependencies
- Role communication patterns
- Deployment requirements
- Authentication and security constraints

### 5. Production Readiness Assessment
Review the [Service Fabric Production Readiness Checklist](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-production-readiness-checklist) to ensure your future Service Fabric application meets production standards.

## Architecture Planning

### 1. Service Fabric Managed Cluster vs. Traditional Cluster

Service Fabric offers two deployment models:

- **Service Fabric Managed Clusters (Recommended)**: Simplified cluster resource model where Microsoft manages underlying cluster infrastructure.
  - Automated OS patching
  - Simplified deployment and management
  - Reduced operational overhead
  - Built-in security best practices
  - [Learn more about Service Fabric Managed Clusters](https://learn.microsoft.com/en-us/azure/service-fabric/overview-managed-cluster)

- **Traditional Service Fabric Clusters**: Customizable but requires more operational management.

We strongly recommend using **Service Fabric Managed Clusters** for migrations from Cloud Services to simplify operations and ensure better security posture.

### 2. Service Fabric Architecture Patterns

Map your Cloud Services components to Service Fabric architectural patterns:

| Cloud Services Component | Service Fabric Equivalent |
|--------------------------|---------------------------|
| Web Role | Stateless Service with ASP.NET Core |
| Worker Role | Stateless Service with background processing |
| Role Instances | Service Instances and Partitions |
| Role Environment | Service Fabric Application Context |
| Local Storage | Service Fabric local storage volumes |
| RoleEntryPoint | ServiceInstanceListener or RunAsync method |

### 3. Service Fabric Cluster Structure for Managed Clusters

**Basic Managed Cluster Structure:**

```json
{
  "resources": [
    {
      "type": "Microsoft.ServiceFabric/managedClusters",
      "apiVersion": "2022-01-01",
      "name": "[parameters('clusterName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Standard"
      },
      "properties": {
        "dnsName": "[parameters('clusterName')]",
        "adminUserName": "[parameters('adminUserName')]",
        "adminPassword": "[parameters('adminPassword')]",
        "clientConnectionPort": 19000,
        "httpGatewayConnectionPort": 19080,
        "clientCertificateCommonNames": [],
        "clientCertificateThumbprints": [],
        "nodeTypes": [
          {
            "name": "FrontEnd",
            "primaryCount": 5,
            "vmInstanceCount": 5,
            "dataDiskSizeGB": 100,
            "vmImagePublisher": "MicrosoftWindowsServer",
            "vmImageOffer": "WindowsServer",
            "vmImageSku": "2019-Datacenter",
            "vmImageVersion": "latest",
            "vmSize": "Standard_D2s_v3",
            "isPrimary": true
          }
        ]
      }
    }
  ]
}
```

For detailed setup instructions, see [Quickstart: Deploy a Service Fabric managed cluster using ARM templates](https://learn.microsoft.com/en-us/azure/service-fabric/quickstart-managed-cluster-template).

### 4. Security Considerations

Service Fabric security must be properly configured to ensure application and data protection:

- **Cluster Security**: Follow the [Service Fabric Cluster Security](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security) guidelines
- **Application Security**: Implement [Application and Service Security](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-application-and-service-security) recommendations
- **Network Security**: Configure NSGs and firewalls according to [Service Fabric Best Practices for Security](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-best-practices-security)

For managed clusters, many security configurations are handled automatically, but you should still follow security best practices in your application code.

## Migration Strategy

### 1. Choose a Migration Approach

#### Lift and Shift
Minimal changes to application architecture, focusing on adapting existing code to run in Service Fabric.

**Pros:**
- Faster migration timeline
- Lower initial development effort
- Reduced risk of functional changes

**Cons:**
- Doesn't fully leverage Service Fabric capabilities
- May require future refactoring to optimize

#### Refactor to Microservices
Decompose application into microservices for greater scalability and easier maintenance.

**Pros:**
- Full utilization of Service Fabric features
- Improved scalability and resilience
- Better separation of concerns

**Cons:**
- Higher initial development effort
- Requires architectural expertise
- Longer migration timeline

### 2. Migration Phases

1. **Setup Service Fabric Managed Cluster Environment**
   - Create a managed cluster using [Service Fabric Managed Cluster deployment tutorial](https://learn.microsoft.com/en-us/azure/service-fabric/tutorial-managed-cluster-deploy)
   - Configure networking and security
   - Establish CI/CD pipeline for Service Fabric

2. **Migrate Configuration and Settings**
   - Map Cloud Service configuration (.cscfg, .csdef) to Service Fabric application manifests
   - Migrate environment settings to Service Fabric parameters

3. **Migrate Code**
   - Adapt Web Roles to Stateless Services 
   - Adapt Worker Roles to Stateless Services or Reliable Services
   - Migrate Startup Tasks to Service Fabric setup code

4. **Migrate State Management**
   - Implement appropriate state management solutions (Reliable Collections)
   - Migrate persistent state from external stores

5. **Implement Service Communication**
   - Replace role communication with Service Fabric communication patterns
   - Configure service discovery

6. **Test and Optimize**
   - Validate functionality and performance
   - Test scaling and failover scenarios
   - Optimize resource usage

## Step-by-Step Migration Process

### 1. Setting Up a Service Fabric Managed Cluster

```powershell
# Deploy a Service Fabric managed cluster with Azure PowerShell
New-AzResourceGroupDeployment `
  -ResourceGroupName "myResourceGroup" `
  -TemplateFile "sfmanagedcluster.json" `
  -TemplateParameterFile "sfmanagedcluster.parameters.json"
```

For a portal-based setup, follow the [Quickstart: Create a Service Fabric managed cluster](https://learn.microsoft.com/en-us/azure/service-fabric/quickstart-managed-cluster-portal) tutorial.

### 2. Creating Service Fabric Application Projects

- Install Service Fabric SDK and tools
- Create Service Fabric application projects for each component:

```powershell
# Create a new Service Fabric application
dotnet new sfreliable-services-app -n MyServiceFabricApp

# Add a new stateless service
dotnet new sfreliable-services-service --stateless -n MyStatelessService -na MyServiceFabricApp
```

### 3. Migrating Cloud Service Web Roles

1. Create a stateless service with ASP.NET Core
2. Migrate controllers and views
3. Configure service endpoints

```csharp
// Service registration in Program.cs
internal sealed class Program
{
    private static void Main()
    {
        try
        {
            ServiceRuntime.RegisterServiceAsync("WebFrontEndType", 
                context => new WebFrontEnd(context)).GetAwaiter().GetResult();

            ServiceEventSource.Current.ServiceTypeRegistered(
                Process.GetCurrentProcess().Id, typeof(WebFrontEnd).Name);

            Thread.Sleep(Timeout.Infinite);
        }
        catch (Exception e)
        {
            ServiceEventSource.Current.ServiceHostInitializationFailed(e.ToString());
            throw;
        }
    }
}

// Service implementation
internal sealed class WebFrontEnd : StatelessService
{
    public WebFrontEnd(StatelessServiceContext context)
        : base(context)
    { }

    protected override IEnumerable<ServiceInstanceListener> CreateServiceInstanceListeners()
    {
        return new ServiceInstanceListener[]
        {
            new ServiceInstanceListener(serviceContext =>
                new KestrelCommunicationListener(serviceContext, "ServiceEndpoint", (url, listener) =>
                {
                    var builder = WebApplication.CreateBuilder();

                    builder.Services.AddSingleton<StatelessServiceContext>(serviceContext);
                    
                    // Add services to the container
                    builder.Services.AddControllers();
                    builder.Services.AddRazorPages();
                    
                    var app = builder.Build();
                    
                    // Configure middleware
                    if (app.Environment.IsDevelopment())
                    {
                        app.UseDeveloperExceptionPage();
                    }
                    else
                    {
                        app.UseExceptionHandler("/Error");
                        app.UseHsts();
                    }
                    
                    app.UseStaticFiles();
                    app.UseRouting();
                    app.UseAuthorization();
                    
                    app.MapControllers();
                    app.MapRazorPages();
                    
                    return app;
                }))
        };
    }
}
```

### 4. Migrating Cloud Service Worker Roles

1. Create a stateless service with background processing
2. Move worker logic to RunAsync method
3. Implement service events and timers

```csharp
internal sealed class WorkerBackgroundService : StatelessService
{
    private readonly TimeSpan _interval = TimeSpan.FromSeconds(30);
    
    public WorkerBackgroundService(StatelessServiceContext context)
        : base(context)
    { }

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Migrated worker role processing logic
                await ProcessQueueMessagesAsync(cancellationToken);
                await Task.Delay(_interval, cancellationToken);
            }
            catch (Exception ex)
            {
                ServiceEventSource.Current.ServiceMessage(Context, $"Exception in RunAsync: {ex.Message}");
                // Implement appropriate retry logic
            }
        }
    }

    private async Task ProcessQueueMessagesAsync(CancellationToken cancellationToken)
    {
        // Implement your worker logic here
    }
}
```

### 5. Configuration Migration

Service Fabric uses a hierarchical configuration model:

1. **ApplicationManifest.xml**: Application-wide configuration

```xml
<ApplicationManifest ApplicationTypeName="MyApplicationType"
                     ApplicationTypeVersion="1.0.0"
                     xmlns="http://schemas.microsoft.com/2011/01/fabric"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Parameters>
    <Parameter Name="WebFrontEnd_InstanceCount" DefaultValue="-1" />
    <Parameter Name="StorageAccountConnectionString" DefaultValue="" />
    <Parameter Name="ASPNETCORE_ENVIRONMENT" DefaultValue="Production" />
  </Parameters>
  
  <ServiceManifestImport>
    <ServiceManifestRef ServiceManifestName="WebFrontEndPkg" ServiceManifestVersion="1.0.0" />
    <ConfigOverrides>
      <ConfigOverride Name="Config">
        <Settings>
          <Section Name="ConnectionStrings">
            <Parameter Name="StorageAccount" Value="[StorageAccountConnectionString]" />
          </Section>
          <Section Name="Environment">
            <Parameter Name="ASPNETCORE_ENVIRONMENT" Value="[ASPNETCORE_ENVIRONMENT]" />
          </Section>
        </Settings>
      </ConfigOverride>
    </ConfigOverrides>
  </ServiceManifestImport>
</ApplicationManifest>
```

2. **ServiceManifest.xml**: Service-specific configuration

```xml
<ServiceManifest Name="WebFrontEndPkg"
                 Version="1.0.0"
                 xmlns="http://schemas.microsoft.com/2011/01/fabric"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <ConfigPackage Name="Config" Version="1.0.0" />
  <CodePackage Name="Code" Version="1.0.0">
    <EntryPoint>
      <ExeHost>
        <Program>WebFrontEnd.exe</Program>
        <WorkingFolder>CodeBase</WorkingFolder>
      </ExeHost>
    </EntryPoint>
  </CodePackage>
  <Resources>
    <Endpoints>
      <Endpoint Name="ServiceEndpoint" Protocol="http" Port="8080" />
    </Endpoints>
  </Resources>
</ServiceManifest>
```

3. **Settings.xml**: Configuration settings

```xml
<?xml version="1.0" encoding="utf-8" ?>
<Settings xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/2011/01/fabric">
  <Section Name="ConnectionStrings">
    <Parameter Name="StorageAccount" Value="" />
  </Section>
  <Section Name="Environment">
    <Parameter Name="ASPNETCORE_ENVIRONMENT" Value="Production" />
  </Section>
</Settings>
```

### 6. Accessing Configuration in Service Fabric

```csharp
// Accessing configuration in a Service Fabric service
public sealed class WebFrontEnd : StatelessService
{
    private readonly IConfiguration _configuration;
    
    public WebFrontEnd(StatelessServiceContext context)
        : base(context)
    {
        // Load Service Fabric configuration
        var configPackagePath = context.CodePackageActivationContext.GetConfigurationPackageObject("Config").Path;
        
        _configuration = new ConfigurationBuilder()
            .SetBasePath(configPackagePath)
            .AddJsonFile("appsettings.json", optional: true)
            .AddXmlFile("Settings.xml")
            .AddEnvironmentVariables()
            .Build();
    }
    
    protected override IEnumerable<ServiceInstanceListener> CreateServiceInstanceListeners()
    {
        // Create service listeners using configuration
        var connectionString = _configuration.GetSection("ConnectionStrings")["StorageAccount"];
        // Use connection string to configure services
    }
}
```

### 7. Deploy to Service Fabric Managed Cluster

1. Package the Service Fabric application:

```powershell
# Package the Service Fabric application
$appPkgPath = "C:\MyServiceFabricApp\pkg"
Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $appPkgPath -CompressPackage -SkipCopy
```

2. Deploy to a managed cluster:

```powershell
# Connect to the cluster
Connect-ServiceFabricCluster -ConnectionEndpoint "mycluster.westus.cloudapp.azure.com:19000"

# Register and create the application
Register-ServiceFabricApplicationType -ApplicationPackagePathInImageStore MyServiceFabricApp
New-ServiceFabricApplication -ApplicationName fabric:/MyServiceFabricApp -ApplicationTypeName MyServiceFabricAppType -ApplicationTypeVersion 1.0.0
```

You can also use [Azure DevOps pipelines for automated deployments](https://learn.microsoft.com/en-us/azure/service-fabric/how-to-managed-cluster-app-deployment-template) to Service Fabric managed clusters.

## Testing and Validation

### 1. Functional Testing
- Validate all application features
- Test service discovery and communication
- Verify configuration is correctly loaded
- Validate user experience and flows

### 2. Performance Testing
- Compare response times with Cloud Services
- Test under expected user load
- Validate auto-scaling parameters
- Measure resource usage

### 3. Resilience Testing
- Test failover scenarios
- Validate instance recycling behavior
- Test upgrade and rollback processes
- Simulate infrastructure failures

### 4. Validation Checklist
- [ ] All features function correctly
- [ ] Performance meets or exceeds Cloud Services
- [ ] Configuration migration is complete
- [ ] Logging and diagnostics work
- [ ] Security requirements are met
- [ ] Deployment pipeline is established
- [ ] Monitoring and alerting are configured
- [ ] Rollback procedures are documented

## Post-Migration Considerations

### 1. Monitoring and Diagnostics

Configure [Service Fabric monitoring and diagnostics](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-overview) for your application:

- Enable Application Insights
- Configure Service Fabric diagnostic collection
- Set up alerts and dashboards
- Implement health reporting

```csharp
// Adding health reporting in your service
var healthClient = new FabricClient().HealthManager;
var healthReport = new HealthReport(
    serviceName: new Uri("fabric:/MyApp/MyService"),
    sourceId: "MyHealthWatcher",
    healthProperty: "Connectivity",
    healthState: HealthState.Ok,
    description: "Service is connected to dependencies"
);
await healthClient.ReportHealthAsync(healthReport);
```

### 2. Scaling and Optimizing

Service Fabric managed clusters support [manual scaling](https://learn.microsoft.com/en-us/azure/service-fabric/tutorial-managed-cluster-scale) and automatic scaling:

```json
{
  "apiVersion": "2021-05-01",
  "type": "Microsoft.ServiceFabric/managedClusters/nodeTypes",
  "name": "[concat(parameters('clusterName'), '/FrontEnd')]",
  "location": "[parameters('location')]",
  "properties": {
    "vmInstanceCount": 5,
    "primaryCount": 5,
    "dataDiskSizeGB": 100,
    "vmSize": "Standard_D2s_v3"
  }
}
```

### 3. Disaster Recovery Planning

- Configure [Service Fabric backup and restore service](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-overview)
- Implement geo-replication where needed
- Document recovery procedures
- Test disaster recovery scenarios

### 4. Security Posture

Follow security best practices:
- Apply [Service Fabric security best practices](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-best-practices-security)
- Regularly update certificates
- Review network security
- Implement proper authentication and authorization

## Troubleshooting Guide

### 1. Deployment Issues
- Verify application manifest is correct
- Check cluster health and capacity
- Validate service package versions
- Review deployment logs

### 2. Runtime Errors
- Check service logs
- Verify configuration settings
- Validate service communication
- Review health events

### 3. Performance Issues
- Analyze resource usage
- Check partition load
- Validate scaling policies
- Review service code for bottlenecks

### 4. Common Error Scenarios and Resolutions

| Error | Possible Cause | Resolution |
|-------|----------------|------------|
| Service activation failed | Missing dependencies | Verify all dependencies are included in service package |
| Communication failures | Network/firewall issues | Check NSG rules and service endpoints |
| Configuration errors | Parameter mismatches | Validate configuration settings across all layers |
| Scaling issues | Cluster capacity | Review node resource utilization and increase capacity if needed |

## Common Migration Scenarios

### 1. Web Role Migration
For a comprehensive example of migrating a Web Role to Service Fabric, including detailed code examples, configuration changes, and best practices, see [Web Role Migration Example](./WebRole_Migration_Example.md).

### 2. Worker Role Migration
For a comprehensive example of migrating a Worker Role to Service Fabric, including detailed code examples, configuration changes, and best practices, see [Worker Role Migration Example](./WorkerRole_Migration_Example.md).

### 3. State Management Migration
For a comprehensive example of migrating state management to Service Fabric, including detailed code examples, configuration changes, and best practices, see [State Management Migration Example](./StateManagement_Migration_Example.md).

## Additional Resources

- [Azure Service Fabric Documentation](https://learn.microsoft.com/en-us/azure/service-fabric/)
- [Service Fabric Managed Clusters Overview](https://learn.microsoft.com/en-us/azure/service-fabric/overview-managed-cluster)
- [Service Fabric Programming Models](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-choose-framework)
- [Service Fabric Architecture](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-architecture)
- [Service Fabric Production Readiness Checklist](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-production-readiness-checklist)
- [Service Fabric Best Practices for Security](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-best-practices-security)
- [Service Fabric Application and Service Security](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-application-and-service-security)
- [Service Fabric Cluster Security](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security)
- [Microsoft Learn Path: Azure Service Fabric](https://learn.microsoft.com/en-us/training/paths/azure-service-fabric/)
- [Service Fabric Sample Applications](https://github.com/Azure-Samples/service-fabric-dotnet-getting-started) 