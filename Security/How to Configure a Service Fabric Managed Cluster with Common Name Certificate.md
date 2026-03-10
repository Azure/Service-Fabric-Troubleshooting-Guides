# How to Configure a Service Fabric Managed Cluster with Common Name Certificate

Service Fabric managed clusters manage the certificate used by the cluster for communication and authentication automatically. This certificate, known as the 'cluster' certificate, is regenerated periodically and is not configurable. A common name certificate from a Certificate Authority can however be configured as a 'client' certificate to connect to the cluster in addition to the managed cluster certificate or as an application certificate.

> ### ❗️NOTE: Connecting to a managed cluster endpoint, for example Service Fabric Explorer (SFX), a certificate error (NET::ERR_CERT_AUTHORITY_INVALID) will occur regardless of certificate being used or cluster configuration due to the cluster using a managed 'cluster' certificate.

## Prerequisites

- A Certificate Authority (CA) signed certificate with appropriate SubjectName.
- Azure Service Fabric SDK which contains PowerShell 'servicefabric' module. This is available on development machines with Visual Studio or on any active node in a service fabric cluster.
- PowerShell Azure 'Az' modules

## Adding common name certificate as a 'client' certificate for cluster connectivity

Use one of the three options below to add a common name certificate as a 'client' certificate for cluster connectivity.

### Using ARM template to add common name certificate to configuration

If using an ARM template for deployment, add a new 'clients' element to array as shown below. For managed clusters, an ARM template can be generated with the current configuration from Azure portal or from PowerShell using Export-AzResourceGroup. See [How to Export Service Fabric Managed Cluster Configuration](/Deployment/how-to-export-service-fabric-managed-cluster-configuration.md) for detailed information.

- isAdmin - set to true if certificate should have cluster write / management capabilities else set to false for readonly.
- commonName - certificate 'SubjectName' without the 'CN='
- issuerThumbprint - a comma separated string of thumbprints of the Issuing certificates for the common name certificate.

```json
//"clients": [
  {
    "isAdmin": "(Boolean)",
    "commonName": "(String)",
    "issuerThumbprint": "(String),(String),(String),..."
  }
//]
```

### Using Azure Portal to add common name certificate configuration

- In [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview), use [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer) navigate to Subscriptions/{{subscription id}}/ResourceGroups/{{resource group}}/Resources/Microsoft.ServiceFabric/managedClusters/{{cluster name}} in the Azure Portal. For detailed instructions on viewing and modifying resources, see [Managing Azure Resources](../Deployment/managing-azure-resources.md).
- Populate provided 'clients' new element template

  - isAdmin - set to true if certificate should have cluster write / management capabilities else set to false for readonly.
  - commonName - certificate 'SubjectName' without the 'CN='
  - issuerThumbprint - a comma separated string of thumbprints of the Issuing certificates for the common name certificate.

  ```json
  //"clients": [
    {
      "isAdmin": "(Boolean)",
      "commonName": "(String)",
      "issuerThumbprint": "(String),(String),(String),..."
    }
  //]
  ```

- 'PUT' to update configuration.

### Using PowerShell to add common name certificate configuration

Run the commands below to use PowerShell to update the certificate configuration of the cluster.

Variables:

- resourceGroupName - Azure resource group that contains the managed cluster.
- commonName - certificate 'SubjectName' without the 'CN='.
- issuerThumbprint - string array of thumbprints of the Issuing certificates for the common name certificate.
- admin - set to true if certificate should have cluster write / management capabilities else set to false for readonly.

```powershell
$resourceGroupName = ''
$clusterName = $resourceGroupName
$commonName = '*.sfcluster.com'
$issuerThumbprint = @('')
$admin = $false
Add-AzServiceFabricManagedClusterClientCertificate -ResourceGroupName $resourceGroupName `
   -Name $clusterName `
   -CommonName $commonName `
   -IssuerThumbprint $issuerThumbprint `
   -Admin:$admin
```

## Adding common name certificate for application connectivity

If using a common name certificate for application connectivity, the certificate needs to be in an Azure key vault and configured on the 'managedClusters/nodetype'.
This will copy the certificate to each of the nodes into the appropriate certificate store. Before the application can use the certificate, ACL'ing of the certificate will need to be configured. See [How to ACL application certificate private key using ApplicationManifest.xml](./How%20to%20ACL%20application%20certificate%20from%20ApplicationManifest.md).

Use one of the three options below  to add a common name certificate for application connectivity.

### Using ARM template to add common name certificate to nodetype configuration

If using an ARM template for deployment, add a new 'vmSecrets' element to array as shown below. For managed clusters, an ARM template can be generated with the current configuration from Azure portal or from PowerShell using Export-AzResourceGroup. See [How to Export Service Fabric Managed Cluster Configuration](/Deployment/how-to-export-service-fabric-managed-cluster-configuration.md) for detailed information.

- id - Azure key vault id. Example: '/subscriptions/{{subscription id}}/resourceGroups/xxxxxxx/providers/Microsoft.KeyVault/vaults/{{vault name}}'
- certificateStore - 'My'
- certificateUrl - Azure key vault certificate secret. Example: 'https://{{vault name}}.vault.azure.net:443/secrets/{{secret name}}/{{secret}}'

  ```json
  //"vmSecrets": [
  {
    "sourceVault": {
      "id": "string"
    },
    "vaultCertificates": [
      {
        "certificateStore": "My",
        "certificateUrl": "string"
      }
    ]
  }
  //]
  ```

### Using Azure Portal to add common name certificate to node type configuration

- In [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview), use [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer) to navigate to  Subscriptions/{{subscription id}}/ResourceGroups/{{resource group}}/Resources/Microsoft.ServiceFabric/managedClusters/{{cluster name}}/nodeTypes/{{nodetype name}} in the Azure Portal. For detailed instructions on viewing and modifying resources, see [Managing Azure Resources](../Deployment/managing-azure-resources.md).
- Populate provided 'vmSecrets' new element template

  - id - Azure key vault id. Example: '/subscriptions/{{subscription id}}/resourceGroups/xxxxxxx/providers/Microsoft.KeyVault/vaults/{{vault name}}'
  - certificateStore - 'My'
  - certificateUrl - Azure key vault certificate secret. Example: 'https://{{vault name}}.vault.azure.net:443/secrets/{{secret name}}/{{secret}}'

  ```json
  //"vmSecrets": [
      {
        "sourceVault": {
          "id": "(string)"
        },
        "vaultCertificates": [
          {
            "certificateUrl": "(string)",
            "certificateStore": "My"
          }
        ]
      }
  //],  
  ```

- 'PUT' to update configuration.

### Using PowerShell to add common name certificate to nodetype configuration

Run the commands below to use PowerShell to update the configuration of the cluster nodetype.

Variables:

- resourceGroupName - Azure resource group that contains the managed cluster.
- certificateStore - 'My'
- certificateUrl - Azure key vault certificate secret. Example: 'https://{{vault name}}.vault.azure.net:443/secrets/{{secret name}}/{{secret}}'
- nodeTypeName - Name of nodetype  / vmss that is being modified.
- sourceVaultId - Azure key vault id. Example: '/subscriptions/{{subscription id}}/resourceGroups/xxxxxxx/providers/Microsoft.KeyVault/vaults/{{vault name}}'

```powershell
$resourceGroupName = 'sfcluster'
$certificateUrl = '' #'https://{{vault name}}.vault.azure.net:443/secrets/{{secret name}}/{{secret}}'
$certificateStore = 'My'
$clusterName = $resourceGroupName
$nodeTypeName = 'nodetype1'
$sourceVaultId = '' #'/subscriptions/{{subscription id}}/resourceGroups/xxxxxxx/providers/Microsoft.KeyVault/vaults/{{vault name}}'
Add-AzServiceFabricManagedNodeTypeVMSecret -ResourceGroupName $resourceGroupName `
   -ClusterName $clusterName `
   -Name $nodeTypeName `
   -SourceVaultId $sourceVaultId `
   -CertificateUrl $certificateUrl `
   -CertificateStore $certificateStore `
   -Verbose
```

## Adding common name certificate to 'client' machine

For web and PowerShell connectivity to a managed cluster, the client certificate needs to be installed on the client machine. Typically this will be in the CurrentUser/My store which will work automatically for both web and PowerShell.

1. Open certmgr.msc on client machine that will be used to connect to cluster and select 'Personal' / 'Certificates'.
2. Right click on 'Certificates', select 'All Tasks' / 'Import...'
3. Browse to certificate .pfx file to import.

## Using common name for DNS resolution to connect to a managed cluster

In an unmanaged cluster, if configuring for use with a common name certificate, the 'managementEndpoint' can be modified to match the certificates SubjectName / common name for DNS resolution. For Service Fabric Managed  clusters, the managementEndpoint is not configurable. To resolve the name of the managed cluster using the certificates common name, an external configuration using DNS resolution is necessary, for example, by adding a CNAME record to DNS for the cluster FQDN address ({{cluster}}.{{location}}.cloudapp.azure.com).

## PowerShell commands to get cluster server certificate thumbprint

Run the commands below to use PowerShell to enumerate the managed cluster 'cluster' / server certificate.

```powershell
  $subscriptionId = ''
  $resourceGroupName = ''
  $managedClusterName = $resourceGroupName
  $clusterResource = Get-AzResource -ResourceId "/subscriptions/$subscriptionId/resourcegroups/$resourceGroupName/providers/Microsoft.ServiceFabric/managedClusters/$managedClusterName"
  $serverThumbprint = $clusterResource.Properties.clusterCertificateThumbprints
  write-host "server thumbprint:$serverThumbprint"
```

## PowerShell command to connect to cluster

Run the commands below to use PowerShell to connect to the managed cluster.

```powershell
$managementEndpoint = 'sfcluster.eastus.cloudapp.azure.com' # {{cluster name}}.{{location}}.cloudapp.azure.com
$managementPort = 19000
$serverThumbprint = ''
$certificateCommonName = '*.sfcluster.com'
Connect-ServiceFabricCluster -ConnectionEndpoint "$managementEndpoint`:$managementPort" `
        -ServerCertThumbprint $serverThumbprint `
        -StoreLocation CurrentUser `
        -StoreName My `
        -X509Credential `
        -FindType FindBySubjectName `
        -FindValue $certificateCommonName `
        -Verbose
```

## Example PowerShell script

The following script performs the commands documented in this TSG to connect to a Service Fabric Managed Cluster.

```powershell
invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/sfmc-connect.ps1" -outFile "$pwd\sfmc-connect.ps1";
.\sfmc-connect.ps1 -clusterEndpoint sfcluster.eastus.cloudapp.azure.com -commonName *.sfcluster.com
```

## Troubleshooting

- Verify the common name certificate is time valid and not revoked.
- Verify there are not multiple certificates installed with same common name.
- Verify the common name certificate being used is installed on machine where PowerShell commands are being executed. Opening Certmgr.msc on machine will open the 'CurrentUser' certificate store.
- Verify that all of the Issuer certificates thumbprints are configured for 'issuerThumbprint' in cluster 'clients' configuration for common name certificate. Renewed certificates may not have the same Issuer thumbprints.
- Verify network connectivity to the managed cluster. By default, PowerShell connects to Service Fabric over port 19000. Use 'test-netConnection' to test network connectivity.

  ```powershell
  $clusterEndpoint = 'sfcluster.eastus.cloudapp.azure.com' # {{cluster name}}.{{location}}.cloudapp.azure.com
  $managementPort = 19000
  Test-NetConnection -computername $clusterEndpoint -port $managementPort

  ComputerName     : sfcluster.eastus.cloudapp.azure.com
  RemoteAddress    : xxx.xxx.xxx.xxx
  RemotePort       : 19000
  InterfaceAlias   : Ethernet 3
  SourceAddress    : xxx.xxx.xxx.xxx
  TcpTestSucceeded : True
  ```

- Verify Service Fabric server certificate thumbprint as this is automatically regenerated on average every 90 days. This thumbprint is viewable in the Azure Portal or using the PowerShell commands documented above [PowerShell commands to get cluster server certificate thumbprint](#powershell-commands-to-get-cluster-server-certificate-thumbprint). For detailed instructions on viewing resources in the Azure Portal, see [Managing Azure Resources](../Deployment/managing-azure-resources.md).

## Reference

[Connect to a Service Fabric managed cluster](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-connect)

[Microsoft.ServiceFabric managedClusters](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/managedclusters?pivots=deployment-language-arm-template)

[Microsoft.ServiceFabric managedClusters/nodeTypes](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/managedclusters/nodetypes?pivots=deployment-language-arm-template)

[Tutorial: Import a certificate in Azure Key Vault](https://learn.microsoft.com/azure/key-vault/certificates/tutorial-import-certificate?tabs=azure-portal)

[Add-AzServiceFabricManagedNodeTypeVMSecret](https://learn.microsoft.com/powershell/module/az.servicefabric/add-azservicefabricmanagednodetypevmsecret)

[Add-AzServiceFabricManagedClusterClientCertificate](https://learn.microsoft.com/powershell/module/az.servicefabric/add-azservicefabricmanagedclusterclientcertificate)
