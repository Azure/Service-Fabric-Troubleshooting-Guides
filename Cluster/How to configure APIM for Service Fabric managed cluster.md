# How to configure APIM Service Fabric Managed Cluster Service Connection

The steps below describe how to configure [Azure API Management](https://learn.microsoft.com/azure/api-management/) (APIM) to route traffic to a back-end service in a Service Fabric managed cluster using PowerShell.

Service Fabric Managed Clusters provision and manage the 'server' certificate including the rollover process before certificate expiration.
There is currently no notification when this occurs.
APIM service connections use X509 Certificate authentication requiring the configuration of the server certificate thumbprint.
When the certificate is rolled over, the APIM connection will fail to connect to cluster causing applications to fail.

## Requirements

- Service Fabric managed cluster deployed using an existing external virtual network. See [Bring your own virtual network](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking#bring-your-own-virtual-network) in [Configure network settings for Service Fabric managed clusters](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking) for additional  information.
- [Azure API Management](https://learn.microsoft.com/azure/api-management/).

## Process

- Verify [Requirements](#requirements).
- [Test](#test) connection.

## Steps

1. First, use New-AzResourceGroup to create a resource group to host the virtual network. Run the following code to create a resource group named TestRG in the eastus 2 Azure region.

    ```powershell
    $rg = @{
        Name = 'TestRG'
        Location = "eastus"
    }

    New-AzResourceGroup @rg
    ```

1. Use New-AzVirtualNetwork to create a virtual network named VNet with IP address prefix 10.0.0.0/16 in the TestRG resource group and eastus 2 location.

    ```powershell
    $vnet = @{
        Name = 'VNet'
        ResourceGroupName = $rg.name
        Location = $rg.location
        AddressPrefix = '10.0.0.0/16'
    }

    $virtualNetwork = New-AzVirtualNetwork @vnet
    ```

1. Create a Network Security Group for APIM

    ```powershell
    $networkSecurityGroup = New-AzNetworkSecurityGroup -Name 'vnet-apim-nsg' -ResourceGroupName $rg.Name  -Location $rg.Location
    ```

1. Configure NSG rules for APIM (Management endpoint for Azure portal and PowerShell)

    ```powershell
    Add-AzNetworkSecurityRuleConfig -Name 'AllowManagementEndpoint' `
      -NetworkSecurityGroup $networkSecurityGroup `
      -Description "Management endpoint for Azure portal and PowerShell" `
      -Access Allow `
      -Protocol Tcp `
      -Direction Inbound `
      -Priority 300 `
      -SourceAddressPrefix ApiManagement `
      -SourcePortRange * `
      -DestinationAddressPrefix VirtualNetwork `
      -DestinationPortRange 3443

    ## Updates the network security group. ##
    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $networkSecurityGroup
    ```

    > Note: Create more rules as needed as per [https://learn.microsoft.com/azure/api-management/virtual-network-reference?tabs=stv2#required-ports](https://learn.microsoft.com/azure/api-management/virtual-network-reference?tabs=stv2#required-ports)

1. Use Add-AzVirtualNetworkSubnetConfig to create a subnet configuration named default with address prefix 10.0.0.0/24.

    ```powershell
    $sfmcSubnet = @{
        Name = 'sfmc'
        VirtualNetwork = $virtualNetwork
        AddressPrefix = '10.0.0.0/24'
    }

    $apimSubnet = @{
        Name = 'apim'
        VirtualNetwork = $virtualNetwork
        AddressPrefix = '10.0.1.0/24'
      NetworkSecurityGroup = $networkSecurityGroup
    }

    Add-AzVirtualNetworkSubnetConfig @sfmcSubnet
    Add-AzVirtualNetworkSubnetConfig @apimSubnet
    ```

1. Then associate the subnets configuration to the virtual network with Set-AzVirtualNetwork.

    ```powershell
    $virtualNetwork | Set-AzVirtualNetwork
    ```

1. Prepare the steps for SFMC BYOVNET as per [https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking#bring-your-own-virtual-network](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking#bring-your-own-virtual-network)

    - Get the service Id from your subscription for Service Fabric Resource Provider application:

      ```powershell
      $sfrpPrincipals = @(Get-AzADServicePrincipal -DisplayName "Azure Service Fabric Resource Provider")
      ```

    - Obtain the SubnetId from the existing VNet:

      ```powershell
      $sfmcSubcriptionId = ((Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $rg.name).Subnets | Where Name -eq $sfmcSubnet.Name | Select Id).Id
      ```

    - Run the following PowerShell command using the principal ID from previous steps, and assignment scope Id obtained above:

      ```powershell
      foreach($sfrpPrincipal in $sfrpPrincipals) {
        New-AzRoleAssignment -PrincipalId $sfrpPrincipal.Id -RoleDefinitionName "Network Contributor" -Scope $sfmcSubscriptionId
      }
      ```

1. Create a Public IP Address (for APIM)

    ```powershell
    $domainNameLabel = 'apimip'
    $ip = @{
        Name = 'apimip'
        ResourceGroupName = $rg.name
        Location = $rg.location
        Sku = 'Standard'
        AllocationMethod = 'Static'
        IpAddressVersion = 'IPv4'
        DomainNameLabel = $domainNameLabel
    }

    New-AzPublicIpAddress @ip
    ```

1. Create API Management Service (It takes around 1 hour)

    ```powershell
    $apimSubnetId = ((Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $rg.name).Subnets | Where Name -eq $apimSubnet.Name | Select Id).Id
    $apimNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $apimSubnetId
    $publicIpAddressId = (Get-AzPublicIpAddress -Name $ip.name -ResourceGroupName $rg.name | Select Id).Id
    $apimName = 'myApimCloud'
    $adminEmail = 'admin@contoso.com'

    New-AzApiManagement -ResourceGroupName $rg.name `
      -Location $rg.location `
      -Name $apimName `
      -Organization "Microsoft" `
      -AdminEmail $adminEmail `
      -VirtualNetwork $apimNetwork `
      -VpnType "External" `
      -Sku "Developer" `
      -PublicIpAddressId $publicIpAddressId
    ```

1. Create the SFMC within the VNET previously created.
    <!-- TODO -->
    > Find the sfmc.json ARM template [here](/.attachments/Azure-APIM/arm-templates/sfmc.json)

    ```powershell
    $sfmc = @{
      clusterName = 'mysfmtestcluster'
      location = $rg.Location
      clusterSku = 'Basic'
      adminUserName = 'marroyo'
      adminPassword = '<enter a password>'
      clusterUpgradeCadence = 'Wave0'
      clientConnectionPort = 19000
      httpGatewayConnectionPort = 19080
      clients = @(
        @{
            isAdmin = $true
            thumbprint = '<enter a thumbprint>'
        }
      )
      loadBalancingRules = @(
        @{
          frontendPort = 80
          backendPort = 80
          protocol = 'tcp'
          probeProtocol = 'tcp'
        }
        @{
          frontendPort = 443
          backendPort = 443
          protocol = 'tcp'
          probeProtocol = 'tcp'
        }
        @{
          frontendPort = 3000
          backendPort = 3000
          protocol = 'tcp'
          probeProtocol = 'tcp'
        }
      )
      nodeType1name = 'nodetype1'
      nodeType1vmSize = 'Standard_D2_v2'
      nodeType1vmInstanceCount = 3
      nodeType1dataDiskSizeGB = 256
      nodeType1dataDiskType = 'StandardSSD_LRS'
      nodeType1vmImagePublisher = 'MicrosoftWindowsServer'
      nodeType1vmImageOffer = 'WindowsServer'
      nodeType1vmImageSku = '2022-Datacenter'
      nodeType1vmImageVersion = 'latest'
      zonalResiliency = $false
      subnetId = $sfmcSubscriptionId
    }

    New-AzResourceGroupDeployment -Name sfmcDeployment -ResourceGroupName $rg.Name -TemplateFile .\sfmc.json -TemplateParameterObject $sfmc
    ```

1. Deploy a simple ASP.NET Web API service to Service Fabric

1. Create a system-assigned managed identity for APIM

    ```powershell
    # Get an API Management instance
    $apimService = Get-AzApiManagement -ResourceGroupName $rg.Name -Name $apimName

    # Update an API Management instance
    Set-AzApiManagement -InputObject $apimService -SystemAssignedIdentity
    ```

1. Configure Key Vault access using a managed identity.

    ```powershell
    $keyVaultName = 'apimKV'
    $managedIdentityId = (Get-AzADServicePrincipal -SearchString $apimName).Id

    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $managedIdentityId  -PermissionsToSecrets get,list
    ```

1. Create a keyVault Certificate in APIM

    ```powershell
    $secretIdentifier = 'https://apimKV.vault.azure.net/secrets/apimcloud-com/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    $apiMgmtContext = New-AzApiManagementContext -ResourceGroupName $rg.Name -ServiceName $apimName
    $keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier
    
    $kvcertId = 'apimcloud-com'
    $keyVaultCertificate = New-AzApiManagementCertificate -Context $apiMgmtContext -CertificateId $kvcertId -KeyVault $keyvault
    ```

1. Create a Service Fabric Backend in APIM using certificate common name (Get the serverX509Name from the Cluster Manifest)
    <!-- TODO -->
    > Find the apim-backend.json ARM template [here](/.attachments/Azure-APIM/arm-templates/apim-backend.json) 

    ```powershell
    $serviceFabricAppUrl = 'fabric:/myapp/myservice'
    $clusterName = 'mysfmtestcluster'
    $clientThumbprint = ''
    $clusterResource = Get-AzResource -Name $clusterName -ResourceType 'Microsoft.ServiceFabric/managedclusters'
    $cluster = Get-AzServiceFabricManagedCluster -Name $clustername -ResourceGroupName $clusterResource.ResourceGroupName
    $serverCertThumbprint = $clusterResource.Properties.clusterCertificateThumbprints
    $x509CertName = $cluster.ClusterId.Replace('-','')
    $sfmcWellKnownIssuers = @(
      '4A34324798CDE744B6BB83C08FFE12559603972E',
      '7E1B85B7A502F2EA8346F2E74126B5276E34EAF5',
      '88092B4018F3E6441F8C79A8E87BD4168439DE59',
      '9FD805A36EFDFB632705992DBA09DDA6E039F34A',
      'C91D63F5F70A9BBEEE8C2FA38433458314844814',
      'E80D143BE075B64469975A2D5D3761A72B4DE228'
    )

    $serverX509Names = [Collections.ArrayList]::new()
    foreach($issuer in $sfmcWellKnownIssuers) {
        $serverX509Names.Add(@{
          name = "$x509CertName.sfmc.azclient.ms"
          issuerCertificateThumbprint = $issuer
        })
    }

    $backend = @{
      apimName = $apimName
      backendName = 'ServiceFabricBackend'
      description = 'Service Fabric backend'
      clientCertificateThumbprint = $keyVaultCertificate.Thumbprint
      managementEndpoints = @("https://$($cluster.Fqdn):$($cluster.HttpGatewayConnectionPort)")
      maxPartitionResolutionRetries = 5
      serverX509Names = @($serverX509Names)
      protocol = 'http'
      url = $serviceFabricAppUrl
      validateCertificateChain = $false
      validateCertificateName = $false
    }

    $backend | ConvertTo-Json

    New-AzResourceGroupDeployment -Name 'apimBackendDeployment' `
      -ResourceGroupName $rg.Name `
      -TemplateFile "$pwd\apim-backend.json" `
      -TemplateParameterObject $backend
    ```

1. Create an API in APIM

    ```powershell
    $apiId = 'service-fabric-app'
    $apiName = 'Service Fabric App'

    New-AzApiManagementApi -Context $apiMgmtContext `
      -ApiId $apiId `
      -Name $apiName `
      -ServiceUrl "http://servicefabric" `
      -Protocols @("http", "https") `
      -Path "api"
    ```

1. Create an Operation

    ```powershell
    $operationId = 'service-fabric-app-operation'
    $operationName = 'Service Fabric App Operation'

    New-AzApiManagementOperation -Context $apiMgmtContext `
      -ApiId $apiId `
      -OperationId $operationId `
      -Name $operationName `
      -Method "GET" `
      -UrlTemplate "/api/values" `
      -Description ""
    ```

1. Create a Policy

    ```powershell
    $sfResolveCondition = '@((int)context.Response.StatusCode != 200)'
    $policy = "
    <policies>
        <inbound>
            <base />
            <set-backend-service backend-id=`"$($backend.backendName)`" sf-resolve-condition=`"$sfResolveCondition`" sf-service-instance-name=`"$serviceFabricAppUrl`" />
        </inbound>
        <backend>
            <base />
        </backend>
        <outbound>
            <base />
        </outbound>
        <on-error>
            <base />
        </on-error>
    </policies>"

    Set-AzApiManagementPolicy -Context $apiMgmtContext `
      -ApiId $apiId `
      -Policy $policyString `
      -Format 'application/vnd.ms-azure-apim.policy.raw+xml'
    ```

1. Test Connectivity

## Test

<!-- TODO -->

## Troubleshooting
<!-- TODO -->
- Error: ##[debug]System.AggregateException: One or more errors occurred. ---> System.Fabric.FabricTransientException: Could not ping any of the provided Service Fabric gateway endpoints. ---> System.Runtime.InteropServices.COMException: Exception from HRESULT: 0x80071C49
- Test network connectivity to cluster management port. Run PowerShell command 'test-netconnection' command to cluster http endpoint, providing tcp port. Default port is 19080.

  ```powershell
  $clusterEndpoint = 'mysftestcluster.eastus.cloudapp.azure.com'
  $clusterHttpPort = 19080
  Test-NetConnection -ComputerName $clusterEndpoint -Port $clusterHttpPort
  ```

- Verify ability to connect successfully to cluster using PowerShell. The 'servicefabric' module is required and is installed as part of Service Fabric SDK.

  ```powershell
  import-module servicefabric
  import-module az.resources

  $clusterEndpoint = 'mysftestcluster.eastus.cloudapp.azure.com:19000'
  $clusterName = 'mysftestcluster'

  $clusterResource = Get-AzResource -Name $clusterName -ResourceType 'Microsoft.ServiceFabric/managedclusters'
  $serverCertThumbprint = $clusterResource.Properties.clusterCertificateThumbprints

  Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint `
    -AzureActiveDirectory `
    -ServerCertThumbprint $serverCertThumbprint `
    -Verbose
  ```
