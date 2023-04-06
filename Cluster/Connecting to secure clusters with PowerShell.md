# Connecting to Service Fabric clusters with PowerShell

To connect to a Service Fabric cluster from PowerShell, cmdlet [Connect-ServiceFabricCluster](https://learn.microsoft.com/powershell/module/servicefabric/connect-servicefabriccluster) is used.

## **Connect to Service Fabric Managed Clusters**

Service Fabric Managed Cluster connection requires the use of the 'cluster' certificate which is generated internally and rotates automatically.
Additional options are documented here for managed clusters: [Connect to a Service Fabric managed cluster](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-connect)

Service Fabric Managed Cluster X509 connection example.

```powershell
#For X509 based authentication to managed cluster
$clusterEndpoint = 'mysftestcluster.eastus.cloudapp.azure.com:19000'
$clusterName = 'mysftestcluster'
$clientThumbprint = ''
$clusterResource = Get-AzResource -Name $clusterName -ResourceType 'Microsoft.ServiceFabric/managedclusters'
$serverCertThumbprint = $clusterResource.Properties.clusterCertificateThumbprints

Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint `
  -X509Credential `
  -ServerCertThumbprint $serverCertThumbprint `
  -FindType FindByThumbprint `
  -FindValue $clientThumbprint `
  -StoreLocation CurrentUser `
  -Verbose
```

Service Fabric Managed Cluster AAD connection example.

```powershell
#For AAD based authentication to managed cluster
$clusterEndpoint = 'mysftestcluster.eastus.cloudapp.azure.com:19000'
$clusterName = 'mysftestcluster'

$clusterResource = Get-AzResource -Name $clusterName -ResourceType 'Microsoft.ServiceFabric/managedclusters'
$serverCertThumbprint = $clusterResource.Properties.clusterCertificateThumbprints

Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint `
  -AzureActiveDirectory `
  -ServerCertThumbprint $serverCertThumbprint `
  -Verbose
```

## **Connect to Service Fabric Clusters**

Verbose script example

```powershell
#For Cert based authentication
$ClusterName= "{yourclustername}.{region}.cloudapp.azure.com:19000"
$Certthumprint = "{yourCertificateThumbprint}"

Connect-ServiceFabricCluster -ConnectionEndpoint $ClusterName -KeepAliveIntervalInSec 10 `
    -X509Credential `
    -ServerCertThumbprint $Certthumprint  `
    -FindType FindByThumbprint `
    -FindValue $Certthumprint `
    -StoreLocation CurrentUser `
    -StoreName My
```

Compact script example

```powershell
#For Cert based authentication
$ClusterName= "{yourclustername}.{region}.cloudapp.azure.com:19000"
$Certthumprint = "{yourCertificateThumbprint}"

#single command - compact example
$connectArgs = @{  ConnectionEndpoint = $ClusterName;  X509Credential = $True;  StoreLocation = "CurrentUser";  StoreName = "My";  FindType = "FindByThumbprint";  FindValue = $Certthumprint; ServerCertThumbprint =$Certthumprint;  }
Connect-ServiceFabricCluster @connectArgs
```

Unsecure cluster connection

```powershell
#For unsecure based authentication
$ClusterName= "{yourclustername}.{region}.cloudapp.azure.com:19000"

#single command - compact example
$connectArgs = @{  ConnectionEndpoint = $ClusterName;   }
Connect-ServiceFabricCluster @connectArgs
```

Simple AAD Authentication

```powershell
$ClusterName= "{yourclustername}.{region}.cloudapp.azure.com:19000"
$Certthumprint = "{yourCertificateThumbprint}"
Connect-ServiceFabricCluster -ConnectionEndpoint $ClusterName -KeepAliveIntervalInSec 10 -AzureActiveDirectory -ServerCertThumbprint $Certthumprint
```

Custom AAD Authentication

```powershell
$TenantID = "<guid>"
$AppIDWeb = "<guid>" #ClientID for webApp
$AppIDNative = "<guid>" #ClientID for nativeApp
[System.Uri]$Uri = New-Object System.Uri("urn:ietf:wg:oauth:2.0:oob"); #RedirectURI for nativeApp
[string]$adTenant              = "<Tenantname>"
[string]$SubscriptionId        = "<SubID>"
[string]$TokenEndpoint = "https://login.windows.net/$($adTenant)/oauth2/token"

# User Credentials
[string]$UserName              = "<username>"
[string]$Password              = "<password>"
[string]$UserAuthPayload = "resource=$($AppIDWeb)&client_id=$($AppIDNative)"+"&grant_type=password&username=$($userName)&password=$($password)&scope=openid";

$auth = Invoke-RestMethod -Uri $TokenEndpoint -body $UserAuthPayload -Headers @{ "Content-Type" = "application/x-www-form-urlencoded"; } -Method Post

$ClusterName= "{yourclustername}.{region}.cloudapp.azure.com:19000"
Connect-ServiceFabricCluster -AzureActiveDirectory -ConnectionEndpoint $ClusterName -SecurityToken $auth.access_token
```

## Troubleshooting connection over a specific port

```powershell
Test-NetConnection -ComputerName "contosocluster.westus2.cloudapp.azure.com" -Port 19000 -InformationLevel "Detailed"

    ComputerName : contosocluster.westus2.cloudapp.azure.com
    RemoteAddress : 13.77.169.134
    RemotePort : 19000
    NameResolutionResults : 13.77.169.134
    MatchingIPsecRules :
    NetworkIsolationContext : Internet
    IsAdmin : False
    InterfaceAlias : Ethernet
    SourceAddress : 65.53.68.93
    NetRoute (NextHop) : 65.53.64.1
    TcpTestSucceeded : True
```

## Connecting to Secure cluster using Service Fabric CLI (sfctl)

Reference: https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cli#select-a-cluster

```powershell
sfctl cluster select --endpoint https://testsecurecluster.com:19080 --pem ./client.pem --no-verify

#Service Fabric CLI supports client-side certificates as PEM (.pem extension) files.
#If you use PFX files from Windows, you must convert those certificates to PEM format.
#To convert a PFX file to a PEM file, use the following command:+

openssl pkcs12 -in certificate.pfx -out client.pem -nodes
```
