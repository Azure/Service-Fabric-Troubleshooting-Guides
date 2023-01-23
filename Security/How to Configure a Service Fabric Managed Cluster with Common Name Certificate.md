# How to Configure a Service Fabric Managed Cluster with Common Name Certificate

## Prerequisites

- A Certificate Authority (CA) signed certificate with appropriate SubjectName.
- Azure Service Fabric SDK which contains PowerShell 'servicefabric' module. This is available on development machines with Visual Studio or on any active node in a service fabric cluster.
- PowerShell Azure 'Az' modules

## Adding common name certificate to cluster configuration

### Using resources.azure.com to add common name certificate configuration

- Open https://resources.azure.com and navigate to {{subscription id}}/resourceGroups/{{resource group}}/providers/Microsoft.ServiceFabric/managedClusters/{{cluster name}}
- Select 'Read/Write' and 'Edit'
- Populate provided 'clients' new element template

  ```json
  //"clients": [
    {
      "isAdmin": "(Boolean)",
      "commonName": "(String)",
      "issuerThumbprint": "(String)"
    }
  //]
  ```

- 'PUT' to update configuration.

### Using PowerShell to add common name certificate configuration

[Add-AzServiceFabricManagedClusterClientCertificate](https://learn.microsoft.com/powershell/module/az.servicefabric/add-azservicefabricmanagedclusterclientcertificate)

```powershell
$resourceGroupName = ''
$clusterName = $resourceGroupName
$commonName = '*.sfcluster.com'
$issuerThumbprint = ''
Add-AzServiceFabricManagedClusterClientCertificate -ResourceGroupName $resourceGroupName `
   -Name $clusterName `
   -CommonName $commonName `
   -IssuerThumbprint $issuerThumbprint `
   -Admin # optional
```

### Using ARM template to add common name certificate to configuration

Add a new 'clients' element to array as shown below

- isAdmin - set to true if certificate should have cluster write / management capabilities else set to false for readonly.
- commonName - certificate 'SubjectName' without the 'CN='
- issuerThumbprint - thumbprint of the Issuing certificate for the common name certificate.

```json
//"clients": [
  {
    "isAdmin": "(Boolean)",
    "commonName": "(String)",
    "issuerThumbprint": "(String)"
  }
//]
```

## Adding common name certificate to 'client' machine

For web and PowerShell connectivity to a managed cluster, the client certificate needs to be installed on the client machine. Typically this will be in the CurrentUser/My store which will work automatically for both web and PowerShell.

1. Open certmgr.msc on client machine that will be used to connect to cluster and select 'Personal' / 'Certificates'.
2. Right click on 'Certificates', select 'All Tasks' / 'Import...'
3. Browse to certificate .pfx file to import.


## PowerShell commands to get cluster server certificate thumbprint

  ```powershell
  $subscriptionId = ''
  $resourceGroupName = ''
  $managedClusterName = $resourceGroupName
  $clusterResource = Get-AzResource -ResourceId "/subscriptions/$subscriptionId/resourcegroups/$resourceGroupName/providers/Microsoft.ServiceFabric/managedClusters/$managedClusterName"
  $serverThumbprint = $clusterResource.Properties.clusterCertificateThumbprints
  write-host "server thumbprint:$serverThumbprint"
  ```

## PowerShell command to connect to cluster

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

## Using common name for DNS resolution to connect to a managed cluster 

In an unmanaged cluster, if configuring for use with a common name certificate, the 'managementEndpoint' can be modified to match the certificates SubjectName / common name for DNS resolution. For Service Fabric Managed  clusters, the managementEndpoint is not configurable. To resolve the name of the managed cluster using the certificates common name, an external configuration using DNS resolution is necessary.

> ### :exclamation:NOTE: Connecting to a managed cluster endpoint for example Service Fabric Explorer (SFX), a certificate error (NET::ERR_CERT_AUTHORITY_INVALID) will occur regardless of certificate being used or configuration due to the cluster using a managed 'cluster' certificate.

### Using Traffic Manager

### Using DNS Zones

### Using DNS CNAME

## Example PowerShell script

The following script performs the commands documented in this TSG to connect to a Service Fabric Managed Cluster.

```powershell
invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/sfm-connect.ps1" -outFile "$pwd\sfm-connect.ps1";
.\sfm-connect.ps1 -clusterEndpoint sfcluster.eastus.cloudapp.azure.com -commonName *.sfcluster.com
```

## Troubleshooting

- Verify the 'client' certificate being used is installed on machine where PowerShell commands are being executed. Opening Certmgr.msc on machine will open the 'CurrentUser' certificate store. 

- Verify the Issuer certificate thumbprint matches 'issuerThumbprint' in cluster 'clients' configuration for common name certificate. Renewed certificates may not have the same Issuer thumbprint.

- Verify network connectivity to the managed cluster. By defualt PowerShell connects to Service Fabric over port 19000. Use 'test-netConnection' to test network connectivity.

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

- Verify Service Fabric server certificate thumbprint as this is automatically regenerated on average every 90 days. This thumbprint is viewable from https://resources.azure.com or using the powershell commands documented above [PowerShell commands to get cluster server certificate thumbprint](#powershell-commands-to-get-cluster-server-certificate-thumbprint).


## Reference

