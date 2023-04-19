<#
.SYNOPSIS
example script configuring apim with service fabric managed cluster

.NOTES
v0.1

Microsoft Privacy Statement: https://privacy.microsoft.com/en-US/privacystatement

MIT License

Copyright (c) Microsoft Corporation. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE

.LINK
To download and execute:
[net.servicePointManager]::Expect100Continue = $true;[net.servicePointManager]::SecurityProtocol = [net.securityProtocolType]::Tls12;
invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/sfmc-apim.ps1" -outFile "$pwd\sfmc-apim.ps1";
.\sfmc-apim.ps1
#>

[cmdletbinding()]
param(
    $resourceGroupName = 'apim',
    $location = 'eastus',
    $vnetName = 'VNet',
    $keyVaultName = 'apimKV',
    $kvcertId = 'apimcloud-com',
    $secretIdentifier = 'https://apimKV.vault.azure.net/secrets/apimcloud-com/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    $apimName = 'myApimCloud',
    $adminEmail = 'admin@contoso.com',
    $adminUserName = 'cloudadmin',
    $adminPassword = '',
    $clusterName = $resourceGroupName,
    $clusterTemplateFile = "$pwd\sfmc-template.json",
    $serviceFabricAppUrl = 'fabric:/myapp/myservice',
    $clientCertificateThumbprint = '',
    $apimBackendTemplate = "$pwd\apim-backend.json",
    $apimIpDomainNameLabel = 'apimip',
    $nodeTypeVmSize = 'Standard_D2s_v3'
)

if (!(Get-AzResourceGroup -Name $rg.Name)) {
    New-AzResourceGroup @rg
}

write-host "create nsg"
$networkSecurityGroup = New-AzNetworkSecurityGroup -Name 'vnet-apim-nsg' -ResourceGroupName $rg.Name  -Location $rg.Location

write-host "configure nsg"
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

write-host "creating vnet"
$vnet = @{
    Name              = 'VNet'
    ResourceGroupName = $rg.name
    Location          = $rg.location
    AddressPrefix     = '10.0.0.0/16'
}

$virtualNetwork = New-AzVirtualNetwork @vnet

write-host "creating subnets"
$sfmcSubnet = @{
    Name           = 'sfmc'
    VirtualNetwork = $virtualNetwork
    AddressPrefix  = '10.0.0.0/24'
}

$apimSubnet = @{
    Name                 = 'apim'
    VirtualNetwork       = $virtualNetwork
    AddressPrefix        = '10.0.1.0/24'
    NetworkSecurityGroup = $networkSecurityGroup
}

Add-AzVirtualNetworkSubnetConfig @sfmcSubnet
Add-AzVirtualNetworkSubnetConfig @apimSubnet

write-host "associating subnets"
$virtualNetwork | Set-AzVirtualNetwork

write-host "retrieving sfrp principal"
$sfrpPrincipals = @(Get-AzADServicePrincipal -DisplayName "Azure Service Fabric Resource Provider")

write-host "getting subnet id"
$sfmcSubnetId = ((Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $rg.name).Subnets | Where-Object Name -eq $sfmcSubnet.Name | Select-Object Id).Id

write-host "assigning roles for sfrp"
foreach ($sfrpPrincipal in $sfrpPrincipals) {
    New-AzRoleAssignment -PrincipalId $sfrpPrincipal.Id -RoleDefinitionName "Network Contributor" -Scope $sfmcSubnetId
}

write-host "creating apim public ip"
$ip = @{
    Name              = 'apimip'
    ResourceGroupName = $rg.name
    Location          = $rg.location
    Sku               = 'Standard'
    AllocationMethod  = 'Static'
    IpAddressVersion  = 'IPv4'
    DomainNameLabel   = $apimIpDomainNameLabel
}

New-AzPublicIpAddress @ip

write-host "creating apim service. this will take a while..."
$apimSubnetId = ((Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $rg.name).Subnets | Where-Object Name -eq $apimSubnet.Name | Select-Object Id).Id
$apimNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $apimSubnetId
$publicIpAddressId = (Get-AzPublicIpAddress -Name $ip.name -ResourceGroupName $rg.name | Select-Object Id).Id

New-AzApiManagement -ResourceGroupName $rg.name `
    -Location $rg.location `
    -Name $apimName `
    -Organization "Microsoft" `
    -AdminEmail $adminEmail `
    -VirtualNetwork $apimNetwork `
    -VpnType "External" `
    -Sku "Developer" `
    -PublicIpAddressId $publicIpAddressId `
    -Verbose `
    -Debug

write-host "creating managed cluster. this will take a while..."
$sfmc = @{
    clusterName                 = $clusterName
    clusterSku                  = 'Standard'
    adminUserName               = $adminUserName
    adminPassword               = $adminPassword
    clientCertificateThumbprint = $clientCertificateThumbprint
    nodeType1name               = 'nodetype1'
    nodeType1vmSize             = $nodeTypeVmSize
    nodeType1vmInstanceCount    = 5
    nodeType1dataDiskSizeGB     = 256
    nodeType1vmImagePublisher   = 'MicrosoftWindowsServer'
    nodeType1vmImageOffer       = 'WindowsServer'
    nodeType1vmImageSku         = '2022-Datacenter'
    nodeType1vmImageVersion     = 'latest'
    subnetId                    = $sfmcSubnetId
}

New-AzResourceGroupDeployment -Name 'sfmcDeployment' `
    -ResourceGroupName $rg.Name `
    -TemplateFile $clusterTemplateFile `
    -TemplateParameterObject $sfmc `
    -DeploymentDebugLogLevel All `
    -Verbose `
    -Debug

write-host "deploy service fabric application before continuing."
pause

write-host "creating system managed identity for apim"
# Get an API Management instance
$apimService = Get-AzApiManagement -ResourceGroupName $rg.Name -Name $apimName
# Update an API Management instance
Set-AzApiManagement -InputObject $apimService -SystemAssignedIdentity

write-host "configuration key vault access using managed identity"
$managedIdentityId = (Get-AzADServicePrincipal -SearchString $apimName).Id
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $managedIdentityId  -PermissionsToSecrets get, list

write-host "creating key vault certificate in apim"
$apiMgmtContext = New-AzApiManagementContext -ResourceGroupName $rg.Name -ServiceName $apimName
$keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier
$keyVaultCertificate = New-AzApiManagementCertificate -Context $apiMgmtContext -CertificateId $kvcertId -KeyVault $keyvault

write-host "creating service fabric backend in apim"
$clusterResource = Get-AzResource -Name $clusterName -ResourceType 'Microsoft.ServiceFabric/managedclusters'
$cluster = Get-AzServiceFabricManagedCluster -Name $clustername -ResourceGroupName $clusterResource.ResourceGroupName

$backend = @{
    apimName                      = $apimName
    backendName                   = 'ServiceFabricBackend'
    description                   = 'Service Fabric backend'
    clientCertificateThumbprint   = $keyVaultCertificate.Thumbprint
    managementEndpoints           = @("https://$($cluster.Fqdn):$($cluster.HttpGatewayConnectionPort)")
    maxPartitionResolutionRetries = 5
    serviceFabricManagedClusterId = $cluster.ClusterId
    protocol                      = 'http'
    url                           = $serviceFabricAppUrl
    validateCertificateChain      = $false
    validateCertificateName       = $false
}

$backend | ConvertTo-Json

New-AzResourceGroupDeployment -Name 'apimBackendDeployment' `
    -ResourceGroupName $rg.Name `
    -TemplateFile $apimBackendTemplate `
    -TemplateParameterObject $backend `
    -DeploymentDebugLogLevel All `
    -Verbose `
    -Debug

write-host "creating api in apim"
$apiId = 'service-fabric-app'
$apiName = 'Service Fabric App'

New-AzApiManagementApi -Context $apiMgmtContext `
    -ApiId $apiId `
    -Name $apiName `
    -ServiceUrl "http://servicefabric" `
    -Protocols @("http", "https") `
    -Path "api"

write-host "creating api operation"
$operationId = 'service-fabric-app-operation'
$operationName = 'Service Fabric App Operation'

New-AzApiManagementOperation -Context $apiMgmtContext `
    -ApiId $apiId `
    -OperationId $operationId `
    -Name $operationName `
    -Method "GET" `
    -UrlTemplate "/api/values" `
    -Description ""

write-host "creating api policy"
$sfResolveCondition = '@((int)context.Response.StatusCode != 200)'
$policyString = "
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
</policies>
"

Set-AzApiManagementPolicy -Context $apiMgmtContext `
    -ApiId $apiId `
    -Policy $policyString `
    -Format 'application/vnd.ms-azure-apim.policy.raw+xml'

write-host 'finished'