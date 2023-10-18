# How to configure Azure Devops for a Service Fabric Cluster

The steps below describe how to configure and Azure Devops (ADO) for Service Fabric clusters. For Service Fabric managed clusters, refer to this article [How to configure Azure Devops Service Fabric Managed Cluster](./how-to-configure-azure-devops-for-service-fabric-managed-cluster.md).  

There are multiple ways to configure Azure Devops for connectivity to Service Fabric clusters. This article will cover different configurations when using a Service Fabric service connection. Service Fabric cluster and application deployment best practice is to use ARM templates. For ARM template deployments in ADO, see [How to configure Azure Devops for Service Fabric ARM deployments](./how-to-configure-azure-devops-for-service-fabric-arm-deployments.md).

## Azure Devops Service Connection Options

For Service Fabric service connection configurations, it is recommended to use Entra (Azure Active Directory / AAD) for authentication and certificate common name for server certificate lookup. This configuration is maintenance free and provides the best security. This is the only service connection configuration that supports parallel deployments per agent host. See [Agent limitations](#agent-limitations).

## Process

- Verify [Requirements](#requirements) and implement [Recommended](#recommended) configurations where possible.
- Configure cluster for [Entra cluster configuration](#entra-cluster-configuration) (AAD) authentication. 
- Configure [Entra user configuration](#entra-user-configuration) for cluster access.
- Test Entra user configuration by connecting to [Service Fabric Explorer (SFX) user test](#service-fabric-explorer-sfx-user-test) as Entra user.
- In Azure Devops, create / modify the [Service Fabric Service Connection](#service-fabric-service-connection) to be used with the build / release pipelines for the cluster.
- [Test](#azure-devops-pipeline-test) connection.

## Requirements

- Secure Service Fabric Cluster. See [Service Fabric cluster security scenarios](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-security).

- ADO agent configured with the latest version of the [Service Fabric SDK](https://learn.microsoft.com/azure/service-fabric/service-fabric-get-started#install-the-sdk-and-tools). This is required for the Service Fabric tasks to work correctly.

- Connectivity from ADO agent to cluster. This can be done by adding the ADO agent IP address to the cluster Network Security Group (NSG) inbound rule for the cluster endpoint port. See [Azure Network Security Group (NSG) Configuration](#azure-network-security-group-nsg-configuration) for more information.

## Recommended

- Secure Service Fabric Cluster with Entra (AAD) enabled.  See [Entra Cluster Configuration](#entra-cluster-configuration) for detailed steps.
- Entra user and password configured to use the Entra 'Cluster' App Registration 'Admin' Role for administrative access to cluster. The 'Cluster' App Registration 'Admin' Role allows read and write access to cluster which is necessary for deployments. See [Entra User Configuration](#entra-user-configuration) for detailed steps.
- Certificate Authority (CA) certificate for cluster connection. This is a best practice and is required for any certificate based authentication using common name.

## Azure Network Security Group (NSG) Configuration

Azure Devops has a [Service Tag](https://learn.microsoft.com/azure/virtual-network/service-tags-overview) name of 'AzureDevops' that can be used when configuring a Network Security Group (NSG) for access to cluster. If using a self-hosted ADO agent, the agent IP address will need to be added to the NSG inbound rule for the cluster endpoint port. If using a ADO agent pool, the agent pool IP address will need to be added to the NSG inbound rule for the cluster endpoint port.

- Source: Service Tag
- Source service tag: AzureCloud
- Source port ranges: *
- Destination: Any
- Service: Custom
- Destination port ranges: 19000
- Protocol: TCP
- Action: Allow
- Priority: 110
- Name: AzureDevopsDeployment

![nsg inbound rule](/media/how-to-configure-azure-devops-for-service-fabric-cluster/ado-nsg-service-tag.png)

> **Important**
> If using a [Service Tag](https://learn.microsoft.com/azure/virtual-network/service-tags-overview) for Azure Devops access to cluster, ensure the NSG inbound rule is using service tag 'AzureCloud' (not 'AzureDevops') and is at minimum configured for the cluster gateway endpoint port. The default port is 19000.

If not using a Service Tag for Azure Devops access to cluster, the ADO agent IP address will need to be added to the NSG inbound rule for the cluster endpoint port. If using a ADO agent pool, the agent pool IP address will need to be added to the NSG inbound rule for the cluster endpoint port. A list of ip ranges being used by ADO can be found [here](https://docs.microsoft.com/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops#ip-ranges).

## Entra Cluster Configuration

Entra configuration for a Service Fabric cluster can be configured either during initial or post cluster deployment. To setup Entra configuration for use with Service Fabric, see [Set up Microsoft Entra ID for client authentication in the Azure portal](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-azure-ad-via-portal) for detailed steps on how to enable Entra for cluster or [Set up Microsoft Entra ID for client authentication](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-aad) for an automated process.

### Entra Cluster Configuration in Azure Portal

Entra Cluster configuration can viewed in [Azure portal](https://portal.azure.com) by navigating to the cluster and selecting 'Security' from the left menu. The 'Azure Active Directory' section will show the Entra configuration.

![portal cluster security](/media/how-to-configure-azure-devops-for-service-fabric-cluster/portal-sfc-security.png)

### Entra Cluster ARM Template Configuration

Below is an example of adding / modifying Entra configuration Service Fabric cluster ARM template after Entra configuration is complete. The 'azureActiveDirectory' object is added to the 'properties' section of the 'Microsoft.ServiceFabric/clusters' resource. See [Service Fabric cluster template reference](https://docs.microsoft.com/azure/templates/microsoft.servicefabric/clusters) for more information on cluster template configuration.

```diff
{
    "apiVersion": "2021-06-01",
    "type": "Microsoft.ServiceFabric/clusters",
    "name": "[parameters('clusterName')]",
    "location": "[parameters('clusterLocation')]",
    "dependsOn": [
        "[concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName'))]"
    ],
    "properties": {
        "addOnFeatures": [
            "DnsService"
        ],
+       "azureActiveDirectory": {
+         "tenantId":"<tenant id>",
+         "clusterApplication":"<cluster application id>",
+         "clientApplication":"<client application id>"
+       },
```

## Entra User Configuration

The Entra user must be added to the 'Cluster' App Registration in the 'Admin' role. This is required for deployments to cluster. The 'Cluster' App Registration is created when Entra is enabled for the cluster. See [Set up Microsoft Entra ID for client authentication in the Azure portal](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-azure-ad-via-portal) for detailed steps on how to enable Entra for cluster or [Set up Microsoft Entra ID for client authentication](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-aad) for an automated process.

### Entra User Configuration Role configuration

- In Azure portal, navigate to the 'Cluster' [App Registrations](https://portal.azure.com/?feature.msaljs=true#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps).
  ![portal cluster app registration](/media/how-to-configure-azure-devops-for-service-fabric-cluster/portal-cluster-app-registration.png)
- Select 'Api Permissions' from the left menu, then 'Enterprise Applications' link.
  ![portal cluster api permissions](/media/how-to-configure-azure-devops-for-service-fabric-cluster/portal-cluster-app-api-permissions.png)
  
- Select 'Users and groups' from the left menu.
  ![portal cluster user overview](/media/how-to-configure-azure-devops-for-service-fabric-cluster/portal-cluster-user-overview.png)
  ![portal cluster app registration users](/media/how-to-configure-azure-devops-for-service-fabric-cluster/portal-cluster-app-registration-users.png)

- Select 'Add user' from the top menu.
- Select 'Users and groups in my organization' from the 'Assign access to' dropdown.
- Enter the Entra user in the 'Select' field.
- Select 'Cluster' from the 'Select role' dropdown.
- Select 'Admin' from the 'Select role' dropdown.
- Select 'Assign' from the bottom menu.
  
  ![portal cluster user applications](/media/how-to-configure-azure-devops-for-service-fabric-cluster/portal-cluster-user-applications.png)

### Entra User Configuration Multi-Factor Authentication (MFA)

If MFA is enabled for the Entra user, it must be disabled for deployments to cluster from ADO. This can be done by creating a new Entra user with MFA disabled, disabling MFA for the existing Entra user, or through MFA policy configuration. See [Microsoft Entra Conditional Access](https://docs.microsoft.com/azure/active-directory/conditional-access/) for more information on MFA policy configuration. In Azure portal, select the Entra user and view the 'Authentication methods' to check MFA configuration for user. MFA configuration can be tested by connecting to Service Fabric Explorer (SFX) as the Entra user. See [Service Fabric Explorer User Test](#service-fabric-explorer-sfx-user-test) for more information.

### Entra User Configuration Password

If the Entra user account is new, ensure the account is not prompting for a password change. This can be tested by connecting to Service Fabric Explorer (SFX) as the Entra user. See [Service Fabric Explorer User Test](#service-fabric-explorer-sfx-user-test) for more information.

> **Note**
> When user password expires, the account will need to be updated in ADO.

## Service Fabric Service Connection

Create / Modify the Service Fabric Service Connection to provide connectivity to Service Fabric cluster from ADO pipelines.
For maintenance free configuration, only 'Azure Active Directory credential' authentication  and 'Common Name' server certificate lookup is supported.

### Service Fabric Service Connection Common Properties

These properties are common to all Service Fabric service connection configurations.

- **Cluster Endpoint:** Enter connection endpoint for cluster. This is in the format of tcp://{{cluster name}}.{{azure region}}.cloudapp.azure.com:{{cluster endpoint port}}.
  - Example: tcp://sfcluster.eastus.cloudapp.azure.com:19000
- **Service connection name:** Enter a descriptive name of connection.
- **Description:** Optionally enter a descriptive name of connection.

### Azure Devops Service Connection with Entra (Azure Active Directory)

Using Entra for the Service Fabric service connection is considered a best practice for security and maintenance. This is the recommended approach for Service Fabric clusters or applications that are not deployed and maintained via ARM templates.

- **Authentication method:** Select 'Azure Active Directory credential'.
- **Server Certificate Lookup (optional):** Select 'Common Name'.
- **Server Common Name** Enter the cluster server certificate common name. This name can also be found in the cluster manifest in Service Fabric Explorer (SFX).
  - Example: sfcluster.contoso.com
- **Username:** Enter an Entra user that has been added to the clusters 'Cluster' App Registration in UPN format. This can be tested by connecting to SFX as the Entra user.
- **Password:** Enter Entra users password. If this is a new user, ensure account is not prompting for a password change. This can be tested by connecting to SFX as the Entra user.

  ![](/media/how-to-configure-azure-devops-for-service-fabric-cluster/ado-aad-common-connection.png)

### Azure Devops Service Connection with Certificate Common Name

If Entra is not an option, the next best approach is to use the certificate common name for server certificate lookup. This approach is maintenance free, but does not provide the same level of security as Entra. This configuration is not supported for parallel deployments per agent host.

- **Authentication method:** Select 'Certificate Based'.
- **Server Certificate Lookup (optional):** Select 'Common Name'.
- **Server Common Name** Enter the cluster server certificate common name. This name can also be found in the cluster manifest in Service Fabric Explorer (SFX).
  - Example: sfcluster.contoso.com
- **Username:** Enter an Entra user that has been added to the clusters 'Cluster' App Registration in UPN format. This can be tested by connecting to SFX as the Entra user.
- **Password:** Enter Entra users password. If this is a new user, ensure account is not prompting for a password change. This can be tested by connecting to SFX as the Entra user.

  ![](/media/how-to-configure-azure-devops-for-service-fabric-cluster/ado-certificate-common-connection.png)

### Azure Devops Service Connection with Certificate Thumbprint

This configuration should only be used if above configuration is not possible. This configuration requires the certificate to be in base64 encoded format. This configuration is not supported for parallel deployments per agent host. When certificate expires, it must be updated in ADO.

- **Authentication method:** Select 'Certificate Based'.
- **Server Certificate Lookup (optional):** Select 'Thumbprint'.
- **Server Certificate Thumbprint(s)** Enter the cluster or server certificate thumbprint. This name can also be found in the cluster manifest in Service Fabric Explorer (SFX).
  - Example: sfcluster.contoso.com
- **Client Certificate:** Enter the 'base64' string of the cluster or client certificate being used for connection to cluster. Use Powershell to convert certificate to base64 string as shown below.
  - Example:

  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\certificate.pfx"))
  ```

  > **Warning**
  > Client certificate 'base64' has to be re-entered every time the service connection is updated. This is a security feature of ADO.

- **Password (optional):** Enter client certificate password if there is one.

  ![](/media/how-to-configure-azure-devops-for-service-fabric-cluster/ado-certificate-thumbprint-connection.png)

## Agent limitations

Any Service Fabric service connection configuration that requires the 'Client Certificate' in base64 encoded format is not supported for parallel deployments per agent host. For security reasons, at start of deployment, the certificate is installed onto the agent host. At end of deployment, the certificate is removed. Any other deployments that are running on the same agent host using this certificate may fail.

Mitigation options:

- Use a Service Fabric service connection with Entra as described [below](#azure-devops-service-connection-with-entra-azure-active-directory).

- Use one agent host per parallel deployment.

- Use ARM templates for cluster or application deployments. See [How to configure Azure Devops for Service Fabric ARM deployments](./how-to-configure-azure-devops-for-service-fabric-arm-deployments.md).

## Service Fabric Explorer (SFX) user test

Use Entra user to connect to Service Fabric Explorer (SFX) to test Entra user configuration. This will verify Entra user has access to cluster and is not prompted for a password change or MFA.

- Open a browser and navigate to the cluster endpoint.
  - Example: https://sfcluster.eastus.cloudapp.azure.com:19080/Explorer
- When prompted, enter Entra user credentials.
- Upon successful login, SFX will be displayed for cluster.

## Azure Devops pipeline test

Use builtin task 'Service Fabric PowerShell' in pipeline to test connection.

```yaml
trigger:
  - main

pool:
  vmImage: "windows-latest"

variables:
  System.Debug: true
  sfServiceConnectionName: serviceFabricConnection

steps:
  - task: ServiceFabricPowerShell@1
    inputs:
      clusterConnection: $(sfServiceConnectionName)
      ScriptType: "InlineScript"
      Inline: |
        $psVersionTable
        $env:connection
        [environment]::getEnvironmentVariables().getEnumerator()|sort Name
```

## Troubleshooting

- Error: ##[debug]System.AggregateException: One or more errors occurred. ---> System.Fabric.FabricTransientException: Could not ping any of the provided Service Fabric gateway endpoints. ---> System.Runtime.InteropServices.COMException: Exception from HRESULT: 0x80071C49
- Test network connectivity. Add a powershell task to pipeline to run 'test-netconnection' command to cluster endpoint, providing tcp port. Default port is 19000.
  - Example:
  
  ```yaml
  - powershell: |
      $psVersionTable
      [environment]::getEnvironmentVariables().getEnumerator()|sort Name
      $publicIp = (Invoke-RestMethod https://ipinfo.io/json).ip
      write-host "---`r`ncurrent public ip:$publicIp" -ForegroundColor Green
      write-host "test-netConnection $env:clusterEndpoint -p $env:clusterPort"
      $result = test-netConnection $env:clusterEndpoint -p $env:clusterPort
      write-host "test net connection result: $($result | fl * | out-string)"
      if(!($result.TcpTestSucceeded)) { throw }
    errorActionPreference: stop
    displayName: "PowerShell Troubleshooting Script"
    failOnStderr: true
    ignoreLASTEXITCODE: false
    env:  
      clusterPort: 19000
      clusterEndpoint: xxxxxx.xxxxx.cloudapp.azure.com
  ```

- Verify configured Entra user is able to logon successfully to cluster using SFX or powershell. The 'servicefabric' module is installed as part of Service Fabric SDK.

  ```powershell
  import-module servicefabric
  import-module az.resources

  $clusterEndpoint = 'sfcluster.eastus.cloudapp.azure.com:19000'
  $clusterName = 'sfcluster'
  $serverCertThumbprint = '<server cert thumbprint>'

  Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint `
    -AzureActiveDirectory `
    -ServerCertThumbprint $serverCertThumbprint `
    -Verbose
  ```

- Use logging from task to assist with issues.
- Enabling System.Debug in build yaml or in release variables will provide additional output.
