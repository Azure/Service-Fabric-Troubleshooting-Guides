# Comprehensive Guide: Migrating from Azure Cloud Services to Service Fabric

This guide provides detailed steps and best practices for migrating applications from Azure Cloud Services to Azure Service Fabric. It builds upon the existing Microsoft documentation and provides practical guidance for both customers and support engineers.

## Table of Contents
1. [Pre-Migration Assessment](#pre-migration-assessment)
2. [Architecture Planning](#architecture-planning)
3. [Migration Strategy](#migration-strategy)
4. [Step-by-Step Migration Process](#step-by-step-migration-process)
5. [Testing and Validation](#testing-and-validation)
6. [Post-Migration Considerations](#post-migration-considerations)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Common Migration Scenarios](#common-migration-scenarios)

## Pre-Migration Assessment

### 1. Application Analysis
- **Current Architecture Review**
  - Document all Web and Worker Roles
  - Map dependencies between roles
  - Identify state management approach
  - List external service dependencies

- **State Management Assessment**
  - Identify stateless vs. stateful components
  - Document current state storage solutions
  - Evaluate potential for Service Fabric stateful services

- **Communication Patterns**
  - Document inter-role communication methods
  - Identify queue-based vs. direct communication
  - Map service discovery requirements

### 2. Technical Requirements
- **Performance Requirements**
  - Document current performance metrics
  - Define target performance goals
  - Identify critical performance paths

- **Scalability Requirements**
  - Current scaling patterns
  - Target scaling requirements
  - Load balancing needs

- **Availability Requirements**
  - Current availability targets
  - Disaster recovery requirements
  - Backup and restore needs

## Architecture Planning

### 1. Service Fabric Application Design
- **Service Types Selection**
  - Stateless Services for Web/Worker Roles
  - Stateful Services for stateful components
  - Actor Model for distributed state

- **Partitioning Strategy**
  - Partition scheme selection
  - State distribution planning
  - Load balancing considerations

### 2. Infrastructure Planning
- **Cluster Design**
  - Node type configuration
  - VM size selection
  - Network topology

- **Security Planning**
  - Authentication/Authorization
  - Network security
  - Certificate management

## Migration Strategy

### 1. Migration Approaches
- **Phased Migration**
  1. Lift and shift of stateless components
  2. Stateful service implementation
  3. Integration and testing
  4. Production deployment

- **Parallel Migration**
  - Run both systems in parallel
  - Gradual traffic migration
  - Feature parity validation

### 2. Risk Mitigation
- **Rollback Planning**
  - Document rollback procedures
  - Maintain old deployment
  - Version control strategy

- **Data Migration**
  - State transfer strategy
  - Data consistency checks
  - Backup procedures

## Step-by-Step Migration Process

### 1. Preparation Phase
```powershell
# 1. Create Service Fabric cluster
New-AzServiceFabricCluster -ResourceGroupName "MyResourceGroup" -Name "MyCluster" -Location "eastus"

# 2. Set up development environment
Install-Package Microsoft.ServiceFabric.Services
```

### 2. Service Migration
1. **Stateless Service Migration**
   ```csharp
   // Cloud Services Worker Role
   public class WorkerRole : RoleEntryPoint
   {
       public override void Run()
       {
           // Existing code
       }
   }

   // Service Fabric Stateless Service
   public class MyStatelessService : StatelessService
   {
       protected override async Task RunAsync(CancellationToken cancellationToken)
       {
           // Migrated code
       }
   }
   ```

2. **Stateful Service Implementation**
   ```csharp
   public class MyStatefulService : StatefulService
   {
       private IReliableDictionary<string, string> _dictionary;

       protected override async Task RunAsync(CancellationToken cancellationToken)
       {
           _dictionary = await StateManager.GetOrAddAsync<IReliableDictionary<string, string>>("myDictionary");
       }
   }
   ```

### 3. Configuration Migration

#### 3.1 Configuration Overview
Service Fabric provides a flexible configuration system that supports:
- Application-level settings
- Service-level settings
- Environment-specific overrides
- Secure configuration management
- Dynamic configuration updates

#### 3.2 Configuration Structure

1. **ApplicationManifest.xml**
   - Defines application-level settings and parameters
   - Enables environment-specific overrides
   - Manages service dependencies and relationships

```xml
<?xml version="1.0" encoding="utf-8"?>
<ApplicationManifest xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                     ApplicationTypeName="MyAppType" 
                     ApplicationTypeVersion="1.0.0" 
                     xmlns="http://schemas.microsoft.com/2011/01/fabric">
  <Parameters>
    <Parameter Name="MyApp_InstanceCount" DefaultValue="1" />
    <Parameter Name="MyApp_ServiceEndpoint" DefaultValue="80" />
    <Parameter Name="MyApp_ConnectionString" DefaultValue="" />
  </Parameters>
  
  <ServiceManifestImport>
    <ServiceManifestRef ServiceManifestName="MyServicePkg" ServiceManifestVersion="1.0.0" />
    <ConfigOverrides>
      <ConfigOverride Name="Config">
        <Settings>
          <Section Name="MySettings">
            <Parameter Name="ConnectionString" Value="[MyApp_ConnectionString]" />
          </Section>
        </Settings>
      </ConfigOverride>
    </ConfigOverrides>
  </ServiceManifestImport>
</ApplicationManifest>
```

2. **Settings.xml**
   - Contains service-specific configuration
   - Supports sections and parameters
   - Can be overridden by ApplicationManifest.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<Settings xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
          xmlns="http://schemas.microsoft.com/2011/01/fabric">
  <Section Name="MySettings">
    <Parameter Name="ConnectionString" Value="" />
    <Parameter Name="MaxRetries" Value="3" />
    <Parameter Name="Timeout" Value="30" />
  </Section>
  
  <Section Name="Logging">
    <Parameter Name="LogLevel" Value="Information" />
    <Parameter Name="EnableFileLogging" Value="true" />
  </Section>
</Settings>
```

#### 3.3 Accessing Configuration in Services

1. **Stateless Service Example**
```csharp
public class MyStatelessService : StatelessService
{
    private IConfiguration _configuration;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Get configuration package
        var configPackage = Context.CodePackageActivationContext.GetConfigurationPackageObject("Config");
        
        // Access settings
        var connectionString = configPackage.Settings.Sections["MySettings"].Parameters["ConnectionString"].Value;
        var maxRetries = int.Parse(configPackage.Settings.Sections["MySettings"].Parameters["MaxRetries"].Value);
        
        // Use configuration
        await ProcessWithRetries(connectionString, maxRetries, cancellationToken);
    }
}
```

2. **Stateful Service Example**
```csharp
public class MyStatefulService : StatefulService
{
    private IConfiguration _configuration;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Get configuration package
        var configPackage = Context.CodePackageActivationContext.GetConfigurationPackageObject("Config");
        
        // Access settings
        var logLevel = configPackage.Settings.Sections["Logging"].Parameters["LogLevel"].Value;
        var enableFileLogging = bool.Parse(
            configPackage.Settings.Sections["Logging"].Parameters["EnableFileLogging"].Value);
        
        // Use configuration
        await InitializeLogging(logLevel, enableFileLogging, cancellationToken);
    }
}
```

#### 3.4 Dynamic Configuration Updates

1. **Register for Configuration Changes**
```csharp
public class MyService : StatelessService
{
    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Register for configuration changes
        Context.CodePackageActivationContext.ConfigurationPackageModifiedEvent += 
            this.CodePackageActivationContext_ConfigurationPackageModifiedEvent;
            
        // Initial configuration processing
        await ProcessConfiguration(Context.CodePackageActivationContext.GetConfigurationPackageObject("Config"));
    }

    private void CodePackageActivationContext_ConfigurationPackageModifiedEvent(
        object sender, PackageModifiedEventArgs<ConfigurationPackage> e)
    {
        // Handle configuration changes
        ProcessConfiguration(e.NewPackage);
    }

    private void ProcessConfiguration(ConfigurationPackage configPackage)
    {
        // Process updated configuration
        var newSettings = configPackage.Settings.Sections["MySettings"];
        UpdateServiceSettings(newSettings);
    }
}
```

2. **Update Configuration via PowerShell**
```powershell
# Update application parameters
$appName = "fabric:/MyApp"
$appVersion = "1.0.0"
$newConnectionString = "Server=myserver;Database=mydb;User Id=myuser;Password=mypassword;"

$appParam = @{
    "MyApp_ConnectionString" = $newConnectionString
}

Update-ServiceFabricApplication -ApplicationName $appName -ApplicationTypeVersion $appVersion -ApplicationParameter $appParam
```

#### 3.5 Secure Configuration Management

1. **Using Azure Key Vault**
```csharp
public class SecureConfigService : StatelessService
{
    private readonly KeyVaultClient _keyVaultClient;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Get Key Vault URL from configuration
        var configPackage = Context.CodePackageActivationContext.GetConfigurationPackageObject("Config");
        var keyVaultUrl = configPackage.Settings.Sections["Security"].Parameters["KeyVaultUrl"].Value;
        
        // Get secret from Key Vault
        var secret = await _keyVaultClient.GetSecretAsync(keyVaultUrl, "MySecret");
        var connectionString = secret.Value;
        
        // Use secure configuration
        await ProcessWithSecureConfig(connectionString, cancellationToken);
    }
}
```

2. **Secure Settings in ApplicationManifest.xml**
```xml
<ApplicationManifest ...>
  <Parameters>
    <Parameter Name="KeyVaultUrl" DefaultValue="" />
  </Parameters>
  
  <ServiceManifestImport>
    <ServiceManifestRef ServiceManifestName="SecureServicePkg" ServiceManifestVersion="1.0.0" />
    <ConfigOverrides>
      <ConfigOverride Name="Config">
        <Settings>
          <Section Name="Security">
            <Parameter Name="KeyVaultUrl" Value="[KeyVaultUrl]" />
          </Section>
        </Settings>
      </ConfigOverride>
    </ConfigOverrides>
  </ServiceManifestImport>
</ApplicationManifest>
```

#### 3.6 Environment-Specific Configuration

1. **Cloud.xml (Production)**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Application xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
             xmlns="http://schemas.microsoft.com/2011/01/fabric">
  <Parameters>
    <Parameter Name="MyApp_InstanceCount" Value="3" />
    <Parameter Name="MyApp_ServiceEndpoint" Value="80" />
    <Parameter Name="MyApp_ConnectionString" Value="Server=prod;Database=prodDB;" />
  </Parameters>
</Application>
```

2. **Local.1Node.xml (Local Development)**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Application xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
             xmlns="http://schemas.microsoft.com/2011/01/fabric">
  <Parameters>
    <Parameter Name="MyApp_InstanceCount" Value="1" />
    <Parameter Name="MyApp_ServiceEndpoint" Value="80" />
    <Parameter Name="MyApp_ConnectionString" Value="Server=localhost;Database=localDB;" />
  </Parameters>
</Application>
```

## Post-Migration Considerations (Additional possible guides to be developed)

### 1. Monitoring and Operations
- **Health Monitoring**
  - Cluster health monitoring
  - Application health monitoring
  - Custom health checks

- **Performance Monitoring**
  - Service metrics
  - Resource utilization
  - Response times

### 2. Maintenance Procedures
- **Application Updates**
  - Rolling updates
  - Version management
  - Rollback procedures

- **Cluster Management**
  - Node maintenance
  - Certificate rotation
  - Security updates

## Troubleshooting Guide

### 1. Common Issues
- **Connection Issues**
- **State Management Issues**


## Common Migration Scenarios

### 1. Web Role Migration
For a comprehensive example of migrating a Web Role to Service Fabric, including detailed code examples, configuration changes, and best practices, see [Web Role Migration Example](./WebRole_Migration_Example.md).

Key aspects covered in the example:
- Project structure migration
- Service implementation
- Configuration management
- Middleware migration
- Dependency injection
- Health monitoring
- Deployment configuration

### 2. Worker Role Migration
For a comprehensive example of migrating a Worker Role to Service Fabric, including detailed code examples, configuration changes, and best practices, see [Worker Role Migration Example](./WorkerRole_Migration_Example.md).

Key aspects covered in the example:
- Background processing implementation
- Queue processing
- State management
- Health monitoring
- Deployment configuration
- Error handling and retry logic

### 3. State Management Migration
For a comprehensive example of migrating state management to Service Fabric, including detailed code examples, configuration changes, and best practices, see [State Management Migration Example](./StateManagement_Migration_Example.md).

Key aspects covered in the example:
- Reliable Collections usage
- Migration strategies
- Data migration
- State backup and restore
- Performance optimization
- Transaction management

## Additional Resources

- [Service Fabric Documentation](https://docs.microsoft.com/azure/service-fabric)
- [Migration Decision Matrix](./Migration_CloudServices_To_ServiceFabric.md)
- [Service Fabric Samples](https://github.com/Azure-Samples/service-fabric-dotnet-getting-started)
- [Service Fabric Best Practices](https://docs.microsoft.com/azure/service-fabric/service-fabric-best-practices-overview) 