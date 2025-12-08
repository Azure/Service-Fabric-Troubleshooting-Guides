# How to configure Service Fabric or Applications to use TLS 1.2 and TLS 1.3

## Executive Summary

**Quick Start Guide:**

- **TLS 1.2**: Supported on all Windows Server versions with Service Fabric. Configure via registry (Option 1) or .exe.config (Option 2).
- **TLS 1.3**: Requires Windows Server 2022+, Service Fabric 10.1CU2+, and cluster configuration changes.

**Critical Requirements for TLS 1.3:**
1. OS: Windows Server 2022 or later (TLS 1.3 not supported on Linux)
2. Service Fabric: Version 10.1CU2 (10.1.1951.9590) or later
3. Cluster Setting: `enableHttpGatewayExclusiveAuthMode = true` in fabricSettings
4. .NET Framework: 4.8+ for application support
5. Token Auth: Separate endpoint (port 19079) required if using Microsoft Entra ID

**Configuration Options:**
- **Option 1**: Machine-wide registry configuration (affects OS and all applications)
- **Option 2**: Application-level .exe.config (per-application control)
- **Script**: Automated via Custom Script Extension ([vmss-cse-tls.ps1](../Scripts/vmss-cse-tls.ps1))

**Verification**: Use Nmap to test ports 19080 (HTTP Gateway), 19079 (token auth), 19000 (cluster mgmt)

---

> [!IMPORTANT]
> **DEPRECATION NOTICE**  
> **TLS 1.0 and TLS 1.1 are officially deprecated** as per [Microsoft TLS Support Ending](https://learn.microsoft.com/lifecycle/announcements/tls-support-ending-10-31-2024). Azure services are enforcing TLS 1.2 minimum on a service-by-service basis, with Azure-wide retirement targeting **August 31, 2025**. Microsoft strongly recommends migrating to TLS 1.2 as the minimum supported version, with TLS 1.3 recommended for new deployments.
>
> **Service-Specific Enforcement**:
> - **Azure Resource Manager**: TLS 1.2+ required - see [Azure Resource Manager TLS support](https://learn.microsoft.com/azure/azure-resource-manager/management/tls-support)
> - **Application Gateway**: TLS 1.2+ recommended - see [Application Gateway TLS policy](https://learn.microsoft.com/azure/application-gateway/application-gateway-ssl-policy-overview)
> - Validate enforcement dates for each Azure service you use

## TLS 1.3 Support in Service Fabric

Azure Service Fabric supports **TLS 1.3** starting with version **10.1CU2 (10.1.1951.9590)** and later. TLS 1.3 offers significant security and performance improvements:

- **Enhanced Security**: Improved cryptographic algorithms, removal of weak cipher suites, and encrypted handshakes
- **Faster Handshakes**: Reduced round trips (1-RTT vs 2-RTT for TLS 1.2)
- **Simplified Cipher Suites**: Only two secure cipher suites (TLS_AES_256_GCM_SHA384 and TLS_AES_128_GCM_SHA256)
- **Forward Secrecy**: All TLS 1.3 connections provide perfect forward secrecy

### Prerequisites for TLS 1.3

To use TLS 1.3 in Service Fabric clusters:

1. **Service Fabric Runtime**: Version 10.1CU2 (10.1.1951.9590) or later
2. **Operating System**: Windows Server 2022 or later (TLS 1.3 requires OS-level support)
3. **Application Compatibility Manifest**: Applications must declare **Windows 10 compatibility** in their manifest. TLS 1.3 will not enable for Service Fabric transport endpoints if the application runs in Windows 8 compatibility mode.
4. **API Version**: 
   - Managed Clusters: API version `2023-12-01-preview` or later (track release notes for GA version)
   - Classic Clusters: API version `2023-11-01-preview` or later (track release notes for GA version)
5. **.NET Framework**: .NET Framework 4.8 or later for application support

> **Important**: Mixed compatibility settings in packaged applications can prevent TLS 1.3 from enabling. Ensure all application manifests declare Windows 10 compatibility.
>
> **Note**: The API versions listed above are preview versions. Prefer GA (generally available) API versions when released. Check [Service Fabric release notes](https://learn.microsoft.com/azure/service-fabric/service-fabric-versions) for the latest stable API versions.

For complete migration guidance, see [Migrate Azure Service Fabric to TLS 1.3](https://learn.microsoft.com/azure/service-fabric/how-to-migrate-transport-layer-security).

## Configuration Options Overview

Below are the available options for configuring TLS protocols and cipher suites. These steps apply to both Service Fabric infrastructure and hosted applications, though specific configurations may need to be adapted based on your environment.

## Option 1 - Machine wide configuration in registry

This configuration is machine-wide, restricting the OS and all applications to use TLS 1.2 or higher with secure cipher suites. For TLS 1.3 support, ensure you're running Windows Server 2022 or later with Service Fabric 10.1CU2+.

> **Important for Azure VMSS Clusters**: Manual registry changes on VMSS instances are **not persistent**. They are lost during:
> - Scale-out operations (new instances won't have the changes)
> - Reimage operations
> - OS upgrades
> - VMSS model updates
>
> **For Azure VMSS-based Service Fabric clusters, use one of these approaches instead**:
> - **Recommended**: Custom Script Extension (see [Automated Configuration via Custom Script Extension](#automated-configuration-via-custom-script-extension) section)
> - Azure Policy (for AD-joined clusters)
> - Desired State Configuration (DSC)
>
> **Manual registry edits are appropriate only for**:
> - Standalone (non-Azure) Service Fabric clusters
> - Development/testing environments with documented manual configuration
> - Troubleshooting/validation scenarios (not production)

### TLS Protocol Configuration

> **Best Practice**: Windows Server 2022 and later enable TLS 1.3 and TLS 1.2 by default with secure cipher suites. **Prefer OS defaults; only override registry settings if audit or compliance requirements mandate explicit configuration.** Where possible, use Group Policy instead of direct registry editing.

TLS protocols are configured via registry keys under `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols`. Each protocol version requires specific DWORD values:

**For TLS 1.3** (Windows Server 2022+ only):
```powershell
# Enable TLS 1.3 Server
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server" /v Enabled /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server" /v DisabledByDefault /t REG_DWORD /d 0 /f

# Enable TLS 1.3 Client
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" /v Enabled /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f
```

**For TLS 1.2** (required minimum):
```powershell
# Enable TLS 1.2 Server
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" /v Enabled /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" /v DisabledByDefault /t REG_DWORD /d 0 /f

# Enable TLS 1.2 Client
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v Enabled /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f
```

**Disable deprecated protocols** (TLS 1.0, TLS 1.1, SSL 3.0, SSL 2.0):
```powershell
# Disable TLS 1.1 Server
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f

# Disable TLS 1.0 Server
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f

# Disable SSL 3.0 Server
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f

# Disable SSL 2.0 Server
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f
```

### TLS 1.3 Cipher Suites

TLS 1.3 uses only two cipher suites, which are automatically enabled on Windows Server 2022 and cannot be customized:

- `TLS_AES_256_GCM_SHA384`
- `TLS_AES_128_GCM_SHA256`

These suites provide forward secrecy and use AEAD (Authenticated Encryption with Associated Data) algorithms, eliminating the need for separate MAC operations.

For more information, see [TLS Cipher Suites in Windows Server 2022](https://learn.microsoft.com/windows/win32/secauthn/tls-cipher-suites-in-windows-server-2022).

### Automated Configuration via Custom Script Extension

This option uses Custom Script Extension with extension sequencing and PowerShell script. [../Scripts/vmss-cse-tls.ps1](../Scripts/vmss-cse-tls.ps1) should be saved to a storage location accessible from Service Fabric nodes during deployment.

The script configures TLS 1.2 and TLS 1.3 (on Windows Server 2022+), and is based on [Troubleshooting applications that don't support TLS 1.2](https://learn.microsoft.com/azure/cloud-services/applications-dont-support-tls-1-2) and disables deprecated protocols (TLS 1.0, 1.1, SSL 2.0, SSL 3.0) and weak ciphers (RC4, 3DES).

### Modify ARM Template to Add Custom Script Extension

- Add new 'CustomScriptExtension' extension to 'Microsoft.Compute/virtualMachineScaleSets' 'extensions' array. In the following example, dotnet framework 4.8 is installed and node is restarted before installation of the Service Fabric extension. See [custom-script-windows](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows) for additional information.

```json
{
  "name": "CustomScriptExtension",
  "properties": {
    "publisher": "Microsoft.Compute",
    "type": "CustomScriptExtension",
    "typeHandlerVersion": "1.8",
    "autoUpgradeMinorVersion": true,
    "settings": {
      "fileUris": [
        "[parameters('customScriptExtensionFileUri')]"
      ],
      "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
    }
  }
},
```

### Modify ARM Template to add extension sequencing on Service Fabric Extension

- Add 'provisionAfterExtensions' array with 'CustomScriptExtension' in 'properties' section of 'ServiceFabric' extension. See [virtual-machine-scale-sets-extension-sequencing](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing) for additional information.

```json
"provisionAfterExtensions": [
    "CustomScriptExtension"
],
```

### Configuration of TLS and ciphers

- Below are diffs from changes using template.json generated from portal after adding CustomScriptExecution and extension sequencing.
Powershell script [../Scripts/vmss-cse-tls.ps1](../Scripts/vmss-cse-tls.ps1) is example script that configures TLS and ciphers.

#### template.json

```diff
diff --git a/internal/template/template.json b/internal/template/template.json
index f362926..ff080f0 100644
--- a/internal/template/template.json
+++ b/internal/template/template.json
@@ -2,6 +2,18 @@
     "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json",
     "contentVersion": "1.0.0.0",
     "parameters": {
+      "customScriptExtensionFile":{
+        "type": "string",
+        "metadata": {
+          "description": "powershell script file name and arguments for custom script extension to execute"
+        }
+      },
+      "customScriptExtensionFileUri":{
+        "type": "string",
+        "metadata": {
+          "description": "uri of the script file for custom script extension to execute"
+        }
+      },
       "clusterLocation": {
         "type": "string",
           "defaultValue": "westus",
@@ -457,9 +469,27 @@
           "virtualMachineProfile": {
             "extensionProfile": {
               "extensions": [
+                {
+                  "name": "CustomScriptExtension",
+                  "properties": {
+                    "publisher": "Microsoft.Compute",
+                    "type": "CustomScriptExtension",
+                    "typeHandlerVersion": "1.8",
+                    "autoUpgradeMinorVersion": true,
+                    "settings": {
+                      "fileUris": [
+                        "[parameters('customScriptExtensionFileUri')]"
+                      ],
+                    "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
+                    }
+                  }
+                },
                 {
                   "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
                   "properties": {
+                    "provisionAfterExtensions": [
+                      "CustomScriptExtension"
+                  ],
                   "type": "ServiceFabricNode",
                   "autoUpgradeMinorVersion": true,
                   "protectedSettings": {
```

#### template.parameters.json

```diff
diff --git a/internal/template/parameters.json b/internal/template/parameters.json
index 289e771..e598691 100644
--- a/internal/template/parameters.json
+++ b/internal/template/parameters.json
@@ -2,6 +2,12 @@
     "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
+      "customScriptExtensionFile":{
+        "value": "vmss-cse-tls.ps1"
+      },
+      "customScriptExtensionFileUri":{
+        "value": "https://{{ %script storage uri% }}/vmss-cse-tls.ps1"
+      },
       "clusterName": {
         "value": "sf-1nt-5n-cse"
       },
```

### Azure VMSS Deployment Best Practices

When deploying TLS configuration to Azure VMSS-based Service Fabric clusters, use Custom Script Extension (CSE) to configure registry settings during instance provisioning:

**1. Deploy Configuration via Custom Script Extension**

The recommended approach is to add TLS configuration to the VMSS model using Custom Script Extension:

```json
{
  "name": "CustomScriptExtension",
  "properties": {
    "publisher": "Microsoft.Compute",
    "type": "CustomScriptExtension",
    "typeHandlerVersion": "1.8",
    "autoUpgradeMinorVersion": true,
    "settings": {
      "fileUris": [
        "https://<storage-account>.blob.core.windows.net/scripts/vmss-cse-tls.ps1"
      ],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File .\\vmss-cse-tls.ps1"
    }
  }
}
```

This ensures:
- TLS configuration is applied to all new instances during scale-out
- Configuration is consistent across the cluster
- Changes are version-controlled in ARM templates
- Settings persist through reimages and OS upgrades

**2. Use Extension Sequencing**

Configure CSE to run **before** the Service Fabric extension to ensure TLS settings are in place before Service Fabric starts:

```json
{
  "name": "ServiceFabricNode",
  "properties": {
    "provisionAfterExtensions": [
      "CustomScriptExtension"
    ],
    "type": "ServiceFabricNode",
    ...
  }
}
```

**3. Apply Changes to Existing Instances**

After updating the VMSS model with CSE configuration, apply to running instances:

```powershell
# Reimage instances to apply new CSE configuration
# This runs the CSE script and applies TLS registry settings
Update-AzVmssInstance -ResourceGroupName <resource-group-name> `
  -VMScaleSetName <vmss-name> `
  -InstanceId "*"
```

> **Note**: Service Fabric typically manages its own upgrade orchestration and doesn't set the VMSS upgrade policy. The upgrade policy is usually left at default (Manual mode). Service Fabric handles rolling upgrades through its own upgrade domain logic.

**4. Monitor Service Fabric Health**

Monitor cluster health during instance reimages:
```powershell
# Check cluster health
Get-ServiceFabricClusterHealth

# Check node status
Get-ServiceFabricNode | Format-Table NodeName, NodeStatus, HealthState

# Check for seed node quorum (critical for cluster availability)
Get-ServiceFabricNode | Where-Object {$_.IsSeedNode -eq $true}
```

**5. Configuration as Code**

Maintain TLS configuration in source control:
- ARM templates with CSE configuration
- PowerShell scripts (e.g., vmss-cse-tls.ps1)
- Parameter files for environment-specific settings
- Version control for audit trail and rollback capability

**6. Avoid Manual Instance-Level Changes**

❌ **Do not**:
- RDP to individual VMSS instances and manually edit registry
- Make configuration changes outside of VMSS model updates
- Expect manual changes to persist (they're lost on reimage/scale-out)

✅ **Do**:
- Update VMSS model with CSE configuration (ARM template)
- Use extension sequencing to run CSE before Service Fabric extension
- Use `Update-AzVmssInstance` to reimage instances with new CSE configuration

For more information, see:
- [Custom Script Extension for Windows](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-windows)
- [Extension sequencing in VMSS](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing)
- [Service Fabric cluster upgrade](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-upgrade)

## Service Fabric TLS 1.3 Cluster Configuration

When enabling TLS 1.3 support in Service Fabric clusters, additional cluster-level configuration is required beyond the OS-level TLS protocol settings.

> **Prerequisites**: See [Prerequisites for TLS 1.3](#prerequisites-for-tls-13) section above for complete requirements (Service Fabric 10.1CU2+, Windows Server 2022+, API versions, etc.).

### Cluster Manifest Settings

The required settings depend on your authentication method:

#### Certificate-Based Authentication Only

If you only use X.509 certificates for authentication, you only need to enable exclusive authentication mode:

**For Managed Clusters:**

```json
{
  "apiVersion": "2023-12-01-preview",
  "type": "Microsoft.ServiceFabric/managedClusters",
  "properties": {
    "fabricSettings": [
      {
        "name": "HttpGateway",
        "parameters": [
          {
            "name": "enableHttpGatewayExclusiveAuthMode",
            "value": "true"
          }
        ]
      }
    ]
  }
}
```

**For Classic VMSS Clusters:**

```json
{
  "apiVersion": "2023-11-01-preview",
  "type": "Microsoft.ServiceFabric/clusters",
  "properties": {
    "fabricSettings": [
      {
        "name": "HttpGateway",
        "parameters": [
          {
            "name": "enableHttpGatewayExclusiveAuthMode",
            "value": "true"
          }
        ]
      }
    ]
  }
}
```

#### Token-Based Authentication (Microsoft Entra ID)

If you use token-based authentication (OAuth 2.0 bearer tokens), you must define a new HTTP endpoint exclusively for token authentication. 

**Why separate endpoints are required**: TLS 1.3 removed support for post-handshake authentication (renegotiation). Service Fabric's runtime cannot dynamically switch between certificate validation and token validation on a single TLS 1.3 endpoint. The solution is to:

1. Keep certificate-based authentication on the existing HTTP Gateway port (19080)
2. Create a dedicated token authentication endpoint on a separate port (example: 19079)
3. Enable exclusive authentication mode to prevent mixed parsing on one endpoint

This is a Service Fabric runtime constraint specific to TLS 1.3, not a limitation of the TLS protocol itself.

**For Managed Clusters with Token Authentication:**

First, define the new token endpoint in the `nodeTypes` section:

```json
{
  "nodeTypes": [
    {
      "name": "[parameters('vmNodeType0Name')]",
      "httpGatewayTokenAuthEndpointPort": "19079"
    }
  ]
}
```

Then enable exclusive authentication mode in `fabricSettings`:

```json
{
  "apiVersion": "2023-12-01-preview",
  "type": "Microsoft.ServiceFabric/managedClusters",
  "properties": {
    "fabricSettings": [
      {
        "name": "HttpGateway",
        "parameters": [
          {
            "name": "enableHttpGatewayExclusiveAuthMode",
            "value": "true"
          }
        ]
      }
    ]
  }
}
```

**For Classic VMSS Clusters with Token Authentication:**

Similar configuration applies - define `httpGatewayTokenAuthEndpointPort` in each node type, then set `enableHttpGatewayExclusiveAuthMode` to true in fabricSettings.

> **API Reference**:
> - [enableHttpGatewayExclusiveAuthMode](https://learn.microsoft.com/dotnet/api/microsoft.azure.management.servicefabric.models.clusterproperties.enablehttpgatewayexclusiveauthmode) - Enables TLS 1.3 support by enforcing exclusive authentication mode
> - [httpGatewayTokenAuthEndpointPort](https://learn.microsoft.com/dotnet/api/microsoft.azure.management.servicefabric.models.nodetypedescription.httpgatewaytokenauthendpointport) - Port for token-based authentication endpoint

### Network Configuration for Token Authentication Port

When using token-based authentication with a dedicated endpoint (port 19079), you must configure load balancer rules and Network Security Group (NSG) rules:

**Load Balancer Rule Example:**

```json
{
  "name": "LBHttpGatewayTokenAuth",
  "properties": {
    "frontendIPConfiguration": {
      "id": "[resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', variables('lbName'), 'LoadBalancerIPConfig')]"
    },
    "backendAddressPool": {
      "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('lbName'), 'LoadBalancerBEAddressPool')]"
    },
    "protocol": "Tcp",
    "frontendPort": 19079,
    "backendPort": 19079,
    "enableFloatingIP": false,
    "idleTimeoutInMinutes": 5,
    "probe": {
      "id": "[resourceId('Microsoft.Network/loadBalancers/probes', variables('lbName'), 'FabricHttpGatewayProbe')]"
    }
  }
}
```

**Network Security Group (NSG) Rule Example:**

```json
{
  "name": "allowHttpGatewayTokenAuth",
  "properties": {
    "protocol": "Tcp",
    "sourcePortRange": "*",
    "destinationPortRange": "19079",
    "sourceAddressPrefix": "*",
    "destinationAddressPrefix": "*",
    "access": "Allow",
    "priority": 2002,
    "direction": "Inbound"
  }
}
```

### Configuration Parameters

- **enableHttpGatewayExclusiveAuthMode**: Boolean value that enables TLS 1.3 support for HTTP Gateway communications. Set to `true` to enable. This is required for all TLS 1.3 configurations.

- **httpGatewayTokenAuthEndpointPort**: Port number for the token authentication endpoint. **Only required if you use token-based authentication (Microsoft Entra ID, formerly Azure Active Directory)**. You can use any port number from the Service Fabric runtime reserved port range (example shows 19079, but any available port can be used). This port must be configured:
  - In the `nodeTypes` section for each node type
  - In your load balancer rules
  - In your Network Security Group (NSG) rules
  - In any scripts or applications that use token-based authentication

> **Note**: For Service Fabric port reference, see the Verification section below.

### Migration Guidance

For detailed guidance on migrating your cluster to TLS 1.3, see [How to migrate Transport Layer Security (TLS) in Service Fabric](https://learn.microsoft.com/azure/service-fabric/how-to-migrate-transport-layer-security).



## Option 2 - Application level configuration by .exe.config

Application-level TLS configuration allows you to control TLS settings for specific .NET Framework applications without affecting the entire machine.

### .NET Framework and TLS Version Support

| .NET Framework Version | TLS 1.2 | TLS 1.3 | Configuration Required |
|------------------------|---------|---------|------------------------|
| 4.8+ | ✅ | ✅ | Uses OS default (recommended) |
| 4.7 - 4.7.2 | ✅ | ❌ | Requires AppContextSwitchOverrides |
| 4.6 - 4.6.2 | ✅ | ❌ | Requires AppContextSwitchOverrides |
| 4.5 - 4.5.2 | ⚠️ | ❌ | Requires registry configuration |
| < 4.5 | ❌ | ❌ | Not supported |

### Recommended Configuration (.NET 4.6+)

For applications using .NET Framework 4.6 or later, configure the application's `.exe.config` file (e.g., `FabricUS.exe.config`) to use system default TLS versions:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <runtime>
        <AppContextSwitchOverrides value="Switch.System.Net.DontEnableSchUseStrongCrypto=false;Switch.System.Net.DontEnableSystemDefaultTlsVersions=false"/>
    </runtime>
</configuration>
```

### Configuration Switches Explained

- **Switch.System.Net.DontEnableSchUseStrongCrypto=false**: Enables strong cryptography and blocks weak protocols. This switch maps to the registry key `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\SchUseStrongCrypto` at the application level.

- **Switch.System.Net.DontEnableSystemDefaultTlsVersions=false**: Allows the application to use the operating system's default TLS version. This is essential for TLS 1.3 support as it defers protocol selection to the OS. This switch maps to the `SystemDefaultTlsVersions` registry key.

### Code-Level Configuration (C#)

For programmatic control, use `SecurityProtocolType.SystemDefault` instead of explicit protocol versions:

```csharp
// Recommended: Let OS choose the protocol (TLS 1.2/1.3 as available)
ServicePointManager.SecurityProtocol = SecurityProtocolType.SystemDefault;

// Not recommended: Hard-coding protocols
// Note: .NET Framework 4.x does NOT define a Tls13 enum value.
// Using SystemDefault allows the framework to defer to OS-level TLS configuration.
```

> **Important**: .NET Framework 4.x does not provide a `SecurityProtocolType.Tls13` enum value. To enable TLS 1.3 support in .NET Framework applications, you must:
> 1. Use `SecurityProtocolType.SystemDefault` in code
> 2. Configure `AppContextSwitchOverrides` in `.exe.config` (see above)
> 3. Ensure the OS supports TLS 1.3 (Windows Server 2022+)
>
> For more information, see [TLS version supported by Azure Resource Manager](https://learn.microsoft.com/azure/azure-resource-manager/management/tls-support).

### Important Notes

- For TLS 1.3 support, applications must run on .NET Framework 4.8+ with Windows Server 2022 or later
- Using `SystemDefault` ensures your application automatically benefits from OS-level security updates
- The `<AppContextSwitchOverrides>` element is documented at [AppContextSwitchOverrides element](https://learn.microsoft.com/dotnet/framework/configure-apps/file-schema/runtime/appcontextswitchoverrides-element)

## Verification

After configuration has been applied and the node has been restarted, verify cluster and application functionality. Once verified, test TLS configuration using tools like [Nmap](https://nmap.org) or [IISCrypto](https://www.nartac.com/Products/IISCrypto/).

### Nmap

To verify TLS configuration with Nmap:

1. [RDP](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to the node
2. Download and install [Nmap](https://nmap.org/download)
3. Run the verification command

**Example command:**
```powershell
# Verify TLS configuration on Service Fabric HTTP Gateway (SFX)
nmap --script ssl-enum-ciphers -p 19080 -Pn <gateway-ip-or-dns>

# Verify token authentication endpoint (if configured for Microsoft Entra ID)
nmap --script ssl-enum-ciphers -p 19079 -Pn <gateway-ip-or-dns>

# Verify cluster management endpoint
nmap --script ssl-enum-ciphers -p 19000 -Pn <gateway-ip-or-dns>
```

### Service Fabric Port Reference

| Port | Purpose | TLS Required | Notes |
|------|---------|--------------|-------|
| 19080 | HTTP Gateway (SFX) | Yes | Certificate-based authentication |
| 19079 | Token Authentication Endpoint | Yes | Only needed for Microsoft Entra ID auth |
| 19000 | Cluster Management | Yes | Internal cluster communications |
| 19081 | Reverse Proxy | Yes | Service-to-service communication |

For more information, see [Visualizing your cluster using Service Fabric Explorer](https://learn.microsoft.com/azure/service-fabric/service-fabric-visualizing-your-cluster).

#### TLS 1.3 Example Output (Windows Server 2022)

```text
PS C:\Program Files (x86)\Nmap> nmap --script ssl-enum-ciphers -p 19080 -Pn 10.0.0.4
Starting Nmap 7.93 ( https://nmap.org ) at 2024-01-15 19:09 Coordinated Universal Time

Nmap scan report for nt0000000.internal.cloudapp.net (10.0.0.4)
Host is up (0.0010s latency).

PORT      STATE SERVICE
19080/tcp open  service-fabric-gateway
| ssl-enum-ciphers:
|   TLSv1.3:
|     ciphers:
|       TLS_AES_256_GCM_SHA384 (ecdh_x25519) - A
|       TLS_AES_128_GCM_SHA256 (ecdh_x25519) - A
|     cipher preference: server
|   TLSv1.2:
|     ciphers:
|       TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (secp384r1) - A
|     compressors:
|       NULL
|     cipher preference: server
|_  least strength: A

Nmap done: 1 IP address (1 host up) scanned in 0.87 seconds
PS C:\Program Files (x86)\Nmap>
```

#### TLS 1.2 Example Output (Legacy Configuration)

> **⚠️ Note**: The following output shows deprecated DHE cipher suites that are no longer recommended and have been removed from Windows Server 2022. These ciphers should be disabled in production environments.

```text
PS C:\Program Files (x86)\Nmap> nmap --script ssl-enum-ciphers -p 19080 -Pn 10.0.0.4
Starting Nmap 7.93 ( https://nmap.org ) at 2022-10-15 19:09 Coordinated Universal Time

Nmap scan report for nt0000000.internal.cloudapp.net (10.0.0.4)
Host is up (0.0010s latency).

PORT      STATE SERVICE
19080/tcp open  service-fabric-gateway
| ssl-enum-ciphers:
|   TLSv1.2:
|     ciphers:
|       TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (secp384r1) - A
|       TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (dh 2048) - A  ⚠️ DEPRECATED
|       TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (dh 2048) - A  ⚠️ DEPRECATED
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (secp384r1) - A
|       TLS_DHE_RSA_WITH_AES_256_CBC_SHA (dh 2048) - A  ⚠️ DEPRECATED
|       TLS_DHE_RSA_WITH_AES_128_CBC_SHA (dh 2048) - A  ⚠️ DEPRECATED
|     compressors:
|       NULL
|     cipher preference: server
|_  least strength: A

Nmap done: 1 IP address (1 host up) scanned in 0.87 seconds
PS C:\Program Files (x86)\Nmap>
```

### Deprecated Cipher Suites

The following cipher suites are deprecated and removed from Windows Server 2022:

- **DHE (Diffie-Hellman Ephemeral)**: All `TLS_DHE_RSA_*` and `TLS_DHE_DSS_*` variants
- **3DES**: `TLS_RSA_WITH_3DES_EDE_CBC_SHA`
- **RC4**: All RC4-based cipher suites
- **RSA Key Exchange without ECDHE**: `TLS_RSA_WITH_AES_*` cipher suites (acceptable but less secure than ECDHE variants)

**Recommended modern cipher suites for TLS 1.2:**

- `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384` (preferred)
- `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256` (preferred)
- `TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384` (fallback only)
- `TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256` (fallback only)

> **Best Practice**: Prefer GCM (Galois/Counter Mode) cipher suites over CBC (Cipher Block Chaining) where possible. GCM provides better performance and is less vulnerable to timing attacks.

**For TLS 1.3** (Windows Server 2022+), only two cipher suites are supported and they are automatically enabled:

- `TLS_AES_256_GCM_SHA384`
- `TLS_AES_128_GCM_SHA256`

## Troubleshooting

### Common TLS Configuration Issues

#### Connection Failures After TLS Configuration

**Problem**: Service Fabric nodes can't communicate after TLS configuration changes.

**Symptoms**:
- Nodes show as down in Service Fabric Explorer
- Certificate validation errors in event logs
- TCP connection failures on Service Fabric ports

**Solution**:

1. Verify TLS protocols are properly configured on **both** client and server:
   ```powershell
   # Check TLS 1.2 Server
   reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
   
   # Check TLS 1.2 Client
   reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"
   ```

2. Check .NET Framework registry keys:
   ```powershell
   # Check SchUseStrongCrypto
   reg query "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto
   reg query "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto
   
   # Check SystemDefaultTlsVersions
   reg query "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions
   reg query "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions
   ```

3. Verify at least one common cipher suite exists between nodes:
   ```powershell
   Get-TlsCipherSuite | Select-Object -First 10 Name
   ```

4. Check event logs for specific TLS errors:
   ```powershell
   Get-WinEvent -LogName "Microsoft-ServiceFabric/Admin" -MaxEvents 50 | Where-Object {$_.Message -like "*TLS*" -or $_.Message -like "*SSL*"}
   ```

#### Missing Cipher Suites

**Problem**: After disabling weak ciphers, applications fail to establish TLS connections. May also manifest as Windows Update error 0x80072EFE or similar connectivity failures.

**Cause**: No common cipher suites between client and server, all cipher suites were disabled, or configured cipher suites don't match what remote servers support (overly restrictive Schannel configuration).

**Solution**:

1. Verify modern cipher suites are enabled:
   ```powershell
   Get-TlsCipherSuite | Where-Object {
       $_.Name -like "TLS_ECDHE_RSA_WITH_AES*GCM*" -or 
       $_.Name -like "TLS_AES*"
   }
   ```

2. If no cipher suites are found, reset to Windows defaults:
   ```powershell
   # Remove Group Policy cipher suite override to restore OS defaults
   reg delete "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002" /f
   
   # Restart required for Schannel to reload defaults
   Restart-Computer -Force
   ```

3. Configure cipher suite ordering using Group Policy:
   - Open Group Policy Editor: `gpedit.msc`
   - Navigate to: Computer Configuration > Administrative Templates > Network > SSL Configuration Settings
   - Configure "SSL Cipher Suite Order" with desired TLS 1.2 cipher suites (semicolon-separated)
   - Example: `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384;TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
   
   > **Note**: TLS 1.3 cipher suites (`TLS_AES_256_GCM_SHA384`, `TLS_AES_128_GCM_SHA256`) are automatically enabled on Windows Server 2022 and cannot be reordered or disabled.
   >
   > For more information, see [TLS registry settings](https://learn.microsoft.com/windows-server/security/tls/tls-registry-settings).

#### TLS 1.3 Not Working

**Problem**: TLS 1.3 is configured but connections fall back to TLS 1.2.

**Requirements Check**:

1. Verify OS version:
   ```powershell
   Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version
   ```
   - Required: Windows Server 2022 (10.0.20348) or later

2. Verify Service Fabric version:
   ```powershell
   Get-ServiceFabricClusterManifest | Select-String "Version"
   ```
   - Required: 10.1CU2 (10.1.1951.9590) or later

3. Verify .NET Framework version:
   ```powershell
   reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Version
   ```
   - Required: 4.8 or later

4. Check cluster manifest for TLS 1.3 settings:
   ```powershell
   Get-ServiceFabricClusterManifest | Select-String "enableHttpGatewayExclusiveAuthMode"
   ```

### Verification Tools

**Nmap**: Test TLS configuration from the network perspective (see Verification section above)

**IIS Crypto**: GUI tool for Windows cipher suite management
- Download from [https://www.nartac.com/Products/IISCrypto/](https://www.nartac.com/Products/IISCrypto/)
- Provides visual interface for enabling/disabling protocols and ciphers
- Shows best practice templates

**SSL Labs**: Online TLS testing (for internet-facing endpoints only)
- Visit [https://www.ssllabs.com/ssltest/](https://www.ssllabs.com/ssltest/)
- Comprehensive security analysis
- Identifies weak configurations and vulnerabilities


## Linux Clusters

Linux-based Service Fabric clusters support TLS configuration through cluster manifest settings and OS-level OpenSSL configuration.

### TLS Protocol Configuration

Update the cluster settings in the Security section:

```json
{
  "name": "Security",
  "parameters": [
    {
      "name": "EnforceLinuxMinTlsVersion",
      "value": "true"
    },
    {
      "name": "TLS1_2_CipherList",
      "value": "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
    }
  ]
}
```

### Configuration Parameters

- **EnforceLinuxMinTlsVersion**: Boolean, default is `false`
  - Set to `true` to enforce TLS 1.2+ only
  - When `false`, allows earlier TLS versions (not recommended)
  - Applies to Service Fabric's Transport and HTTP Gateway

- **TLS1_2_CipherList**: Colon-separated list of OpenSSL cipher suite names
  - Specifies allowed cipher suites for TLS 1.2
  - Example: `"ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"`

### TLS 1.3 Support on Linux

> **Important**: Service Fabric TLS 1.3 support is currently **Windows-only**. Linux-based Service Fabric clusters are not supported for TLS 1.3 at this time, even with OpenSSL 1.1.1+.
>
> For the latest updates on Linux TLS 1.3 support, see [How to migrate Transport Layer Security (TLS) in Service Fabric](https://learn.microsoft.com/azure/service-fabric/how-to-migrate-transport-layer-security).

Linux distributions with OpenSSL 1.1.1 or later provide OS-level TLS 1.3 support, but Service Fabric on Linux does not yet utilize TLS 1.3 for cluster communications. Configure TLS 1.2 as the minimum supported version:

```bash
# Check OpenSSL version
openssl version

# OpenSSL 1.1.1 or later provides TLS 1.3 capability at the OS level
# However, Service Fabric on Linux currently uses TLS 1.2
```

### Machine-Wide TLS Configuration

The Service Fabric `EnforceLinuxMinTlsVersion` setting applies only to Service Fabric processes. For machine-wide TLS settings, configure OpenSSL and system libraries according to your distribution's security guidelines:

- **Ubuntu**: [Ubuntu Security Guide](https://ubuntu.com/security)
- **Red Hat**: [Red Hat Enterprise Linux Security Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/)



## Reference

This guide covers SSL/TLS configuration for Service Fabric clusters and applications. For additional information, consult the following resources:

### Service Fabric TLS Configuration

- [How to migrate Transport Layer Security (TLS) in Service Fabric](https://learn.microsoft.com/azure/service-fabric/how-to-migrate-transport-layer-security) - Complete guide for migrating to TLS 1.3
- [Customize Service Fabric cluster settings - Security](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-fabric-settings#security) - Cluster manifest security settings
- [Connect to a secure cluster](https://learn.microsoft.com/azure/service-fabric/service-fabric-connect-to-secure-cluster) - Securing cluster communications

### Windows Schannel and TLS Configuration

- [TLS Cipher Suites in Windows Server 2022](https://learn.microsoft.com/windows/win32/secauthn/tls-cipher-suites-in-windows-server-2022) - Complete list of supported TLS 1.3 and 1.2 cipher suites
- [Restrict the use of certain cryptographic algorithms and protocols in Schannel.dll](https://learn.microsoft.com/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel) - Registry-level TLS configuration
- [TLS/SSL Settings (Windows)](https://learn.microsoft.com/windows-server/security/tls/tls-ssl-schannel-ssp-overview) - Windows Server TLS/SSL overview
- [Manage TLS/SSL Protocols and Cipher Suites for AD FS](https://learn.microsoft.com/windows-server/identity/ad-fs/operations/manage-ssl-protocols-in-ad-fs) - Cipher suite ordering and management

### .NET Framework TLS Best Practices

- [Transport Layer Security (TLS) best practices with the .NET Framework](https://learn.microsoft.com/dotnet/framework/network-programming/tls) - Comprehensive .NET TLS guidance
- [AppContextSwitchOverrides element](https://learn.microsoft.com/dotnet/framework/configure-apps/file-schema/runtime/appcontextswitchoverrides-element) - Configuration switch documentation
- [Mitigation: TLS Protocols](https://learn.microsoft.com/dotnet/framework/migration-guide/mitigation-tls-protocols) - Framework-specific TLS migration

### Security and Compliance

- [Microsoft TLS Support Ending](https://learn.microsoft.com/lifecycle/announcements/tls-support-ending-10-31-2024) - Official TLS 1.0/1.1 deprecation announcement
- [Azure TLS Support](https://learn.microsoft.com/azure/azure-resource-manager/management/tls-support) - Azure Resource Manager TLS requirements
- [Azure TLS 1.0/1.1 Retirement](https://learn.microsoft.com/azure/security/fundamentals/tls-certificate-changes) - Azure-wide TLS retirement timeline (August 31, 2025)

### Troubleshooting and Verification

- [Nmap - Network Security Scanner](https://nmap.org) - TLS/SSL verification tool
- [IIS Crypto](https://www.nartac.com/Products/IISCrypto/) - GUI tool for Windows cipher suite configuration
- [Qualys SSL Labs Server Test](https://www.ssllabs.com/ssltest/) - Online TLS configuration analysis


