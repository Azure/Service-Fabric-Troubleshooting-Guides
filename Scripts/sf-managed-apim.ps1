<#
.SYNOPSIS
example test script configuring apim with service fabric managed cluster.
used for testing public tsg document .

this script is not to be used directly for production deployments due to many settings being defaulted.
https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Cluster/How%20to%20configure%20APIM%20for%20Service%20Fabric%20managed%20cluster.md

.NOTES
v0.3

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
invoke-webRequest "https://raw.githubusercontent.com/azure/service-fabric-troubleshooting-guides/master/scripts/sf-managed-apim.ps1" -outFile "$pwd\sf-managed-apim.ps1";
.\sf-managed-apim.ps1
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
    $organization = 'contoso',
    $adminPassword = '',
    $clusterName = $resourceGroupName,
    $clusterTemplateFile = "$pwd\sfmc-template.json",
    $serviceFabricAppUrl = 'fabric:/sf-sample-weatherforecast/VotingWebCore', #'fabric:/sfWeatherApiCore/WeatherApi',
    $urlTemplate = '/WeatherForecast',
    $clientCertificateThumbprint = '',
    $apimBackendTemplate = "$pwd\apim-backend.json",
    $apimIpDomainNameLabel = 'apimip',
    $nodeTypeVmSize = 'Standard_D2s_v3'
)

if (!(Get-AzResourceGroup -Name $resourceGroupName)) {
    write-host "creating resource group $resourceGroupName"
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}

write-host "create nsg"
write-host "
New-AzNetworkSecurityGroup -Name 'vnet-apim-nsg' ``
    -ResourceGroupName $resourceGroupName ``
    -Location $location
" -foregroundColor Cyan

$networkSecurityGroup = New-AzNetworkSecurityGroup -Name 'vnet-apim-nsg' `
    -ResourceGroupName $resourceGroupName `
    -Location $location

write-host "configure nsg"
write-host "
Add-AzNetworkSecurityRuleConfig -Name 'AllowManagementEndpoint' ``
    -NetworkSecurityGroup $networkSecurityGroup ``
    -Description 'Management endpoint for Azure portal and PowerShell' ``
    -Access Allow ``
    -Protocol Tcp ``
    -Direction Inbound ``
    -Priority 300 ``
    -SourceAddressPrefix ApiManagement ``
    -SourcePortRange * ``
    -DestinationAddressPrefix VirtualNetwork ``
    -DestinationPortRange 3443
" -foregroundColor Cyan

Add-AzNetworkSecurityRuleConfig -Name 'AllowManagementEndpoint' `
    -NetworkSecurityGroup $networkSecurityGroup `
    -Description 'Management endpoint for Azure portal and PowerShell' `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 300 `
    -SourceAddressPrefix ApiManagement `
    -SourcePortRange * `
    -DestinationAddressPrefix VirtualNetwork `
    -DestinationPortRange 3443

## Updates the network security group. ##
write-host "Set-AzNetworkSecurityGroup -NetworkSecurityGroup $networkSecurityGroup" -foregroundColor Cyan
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $networkSecurityGroup

$vnet = @{
    Name              = 'VNet'
    ResourceGroupName = $resourceGroupName
    Location          = $location
    AddressPrefix     = '10.0.0.0/16'
}

write-host "New-AzVirtualNetwork $($vnet | convertto-json)" -foregroundColor Cyan
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

write-host "Add-AzVirtualNetworkSubnetConfig $($sfmcSubnet | convertto-json)" -foregroundColor Cyan
Add-AzVirtualNetworkSubnetConfig @sfmcSubnet
$sfmcConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork
write-host "sfmc subnet config: $($sfmcConfig | convertto-json)" -foregroundColor Cyan

write-host "Add-AzVirtualNetworkSubnetConfig $($apimSubnet | convertto-json)" -foregroundColor Cyan
Add-AzVirtualNetworkSubnetConfig @apimSubnet
$apimConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork
write-host "apim subnet config: $($apimConfig | convertto-json)" -foregroundColor Cyan

write-host "associating subnets"
$virtualNetwork | Set-AzVirtualNetwork
$vnetConfig = Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $resourceGroupName
write-host "vnet config: $($vnetConfig | convertto-json)" -foregroundColor Cyan

write-host "retrieving sfrp principal"
$sfrpPrincipals = @(Get-AzADServicePrincipal -DisplayName "Azure Service Fabric Resource Provider")
write-host "sfrpPrincipals: $($sfrpPrincipals | convertto-json)" -foregroundColor Cyan

write-host "getting subnet id"
$sfmcSubnetId = ((Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $resourceGroupName).Subnets | Where-Object Name -eq $sfmcSubnet.Name | Select-Object Id).Id
write-host "sfmcSubnetId: $sfmcSubnetId" -foregroundColor Cyan

write-host "assigning roles for sfrp"
foreach ($sfrpPrincipal in $sfrpPrincipals) {
    write-host "New-AzRoleAssignment -PrincipalId $($sfrpPrincipal.Id) -RoleDefinitionName 'Network Contributor' -Scope $sfmcSubnetId" -foregroundColor Cyan
    New-AzRoleAssignment -PrincipalId $sfrpPrincipal.Id -RoleDefinitionName "Network Contributor" -Scope $sfmcSubnetId
}

write-host "creating apim public ip"
$ip = @{
    Name              = 'apimip'
    ResourceGroupName = $resourceGroupName
    Location          = $location
    Sku               = 'Standard'
    AllocationMethod  = 'Static'
    IpAddressVersion  = 'IPv4'
    DomainNameLabel   = $apimIpDomainNameLabel
}

write-host "New-AzPublicIpAddress $($ip | convertto-json)" -ForegroundColor Cyan
New-AzPublicIpAddress @ip

write-host "creating apim service. this will take a while..."
$apimSubnetId = ((Get-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $resourceGroupName).Subnets | Where-Object Name -eq $apimSubnet.Name | Select-Object Id).Id
write-host "apimSubnetId: $apimSubnetId" -foregroundColor Cyan

write-host "New-AzApiManagementVirtualNetwork -SubnetResourceId $apimSubnetId" -foregroundColor Cyan
$apimNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $apimSubnetId
write-host "apimNetwork: $($apimNetwork | convertto-json)" -foregroundColor Cyan

$publicIpAddressId = (Get-AzPublicIpAddress -Name $ip.name -ResourceGroupName $resourceGroupName | Select-Object Id).Id
write-host "publicIpAddressId: $publicIpAddressId" -foregroundColor Cyan

write-host "
New-AzApiManagement -ResourceGroupName $resourceGroupName ``
    -Location $location ``
    -Name $apimName ``
    -Organization $organization ``
    -AdminEmail $adminEmail ``
    -VirtualNetwork $($apimNetwork | convertto-json)``
    -VpnType 'External' ``
    -Sku 'Developer' ``
    -PublicIpAddressId $publicIpAddressId ``
    -Verbose ``
    -Debug
" -ForegroundColor Cyan

New-AzApiManagement -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $apimName `
    -Organization $organization `
    -AdminEmail $adminEmail `
    -VirtualNetwork $apimNetwork `
    -VpnType 'External' `
    -Sku 'Developer' `
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

write-host "
New-AzResourceGroupDeployment -Name 'sfmcDeployment' ``
    -ResourceGroupName $resourceGroupName ``
    -TemplateFile $clusterTemplateFile ``
    -TemplateParameterObject $($sfmc | convertto-json) ``
    -DeploymentDebugLogLevel All ``
    -Verbose ``
    -Force
" -foregroundColor Cyan

New-AzResourceGroupDeployment -Name 'sfmcDeployment' `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $clusterTemplateFile `
    -TemplateParameterObject $sfmc `
    -DeploymentDebugLogLevel All `
    -Verbose `
    -Force

write-host "deploy service fabric application '$serviceFabricAppUrl' to cluster before continuing." -foregroundColor Magenta
pause

write-host "creating system managed identity for apim"
# Get an API Management instance
write-host "Get-AzApiManagement -ResourceGroupName $resourceGroupName -Name $apimName" -foregroundColor Cyan
$apimService = Get-AzApiManagement -ResourceGroupName $resourceGroupName -Name $apimName
write-host "apimservice: $($apimService | convertto-json)" -foregroundColor Cyan

write-host "Set-AzApiManagement -InputObject $apimService -SystemAssignedIdentity" -foregroundColor Cyan
Set-AzApiManagement -InputObject $apimService -SystemAssignedIdentity

write-host "configuration key vault access using managed identity"
$managedIdentityId = (Get-AzADServicePrincipal -SearchString $apimName).Id

# write-host "
# Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName ``
#     -ObjectId $managedIdentityId ``
#     -PermissionsToSecrets get,list ``
#     -PermissionsToCertificates get,list ``
#     -PermissionsToKeys get,list
# " -foregroundColor Cyan

# Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName `
#     -ObjectId $managedIdentityId `
#     -PermissionsToSecrets get, list `
#     -PermissionsToCertificates get, list `
#     -PermissionsToKeys get, list

# $currentUserId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account).Id
# write-host "adding current user to key vault access policy: $currentUserId" -foregroundColor Cyan
# write-host "
# Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName ``
#     -ObjectId $currentUserId ``
#     -PermissionsToSecrets get,list ``
#     -PermissionsToCertificates get,list ``
#     -PermissionsToKeys get,list
# " -foregroundColor Cyan

# Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName `
#     -ObjectId $currentUserId `
#     -PermissionsToSecrets get, list `
#     -PermissionsToCertificates get, list `
#     -PermissionsToKeys get,list
# https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide?tabs=azure-cli#azure-built-in-roles-for-key-vault-data-plane-operations

write-host "getting key vault"
write-host "Get-AzKeyVault -VaultName $keyVaultName" -foregroundColor Cyan
$keyvault = Get-AzKeyVault -VaultName $keyVaultName

if(!$keyvault) {
    write-host "key vault not found. exiting." -foregroundColor Red
    return
}

$roleDefId = (Get-AzRoleDefinition -Name 'Key Vault Reader').Id
$roleSecDefId = (Get-AzRoleDefinition -Name 'Key Vault Secrets User').Id

write-host "
New-AzRoleAssignment -RoleDefinitionId $roleDefId ``
    -ObjectId $managedIdentityId ``
    -Scope $($keyvault.ResourceId)
" -foregroundColor Cyan

New-AzRoleAssignment -RoleDefinitionId $roleDefId `
    -ObjectId $managedIdentityId `
    -Scope $keyvault.ResourceId

write-host "
New-AzRoleAssignment -RoleDefinitionId $roleSecDefId ``
    -ObjectId $managedIdentityId ``
    -Scope $($keyvault.ResourceId)
" -foregroundColor Cyan

New-AzRoleAssignment -RoleDefinitionId $roleSecDefId `
    -ObjectId $managedIdentityId `
    -Scope $keyvault.ResourceId
    
$currentUserId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account).Id
write-host "adding current user to key vault access policy: $currentUserId" -foregroundColor Cyan
write-host "
New-AzRoleAssignment -RoleDefinitionId $roleDefId ``
    -ObjectId $currentUserId ``
    -Scope $($keyvault.ResourceId)
" -foregroundColor Cyan

New-AzRoleAssignment -RoleDefinitionId $roleDefId `
    -ObjectId $currentUserId `
    -Scope $keyvault.ResourceId

write-host "
New-AzRoleAssignment -RoleDefinitionId $roleSecDefId ``
    -ObjectId $currentUserId ``
    -Scope $($keyvault.ResourceId)
" -foregroundColor Cyan

New-AzRoleAssignment -RoleDefinitionId $roleSecDefId `
    -ObjectId $currentUserId `
    -Scope $keyvault.ResourceId

write-host "waiting for key vault access policy to propagate. sleep 5 minutes"
start-sleep -s 300
$count = 0
$maxCount = 10
$policy = $null
while ($count -lt $maxCount -and !$policy) {
    $count++
    write-host "waiting for key vault access policy to propagate $count of $maxCount" -foregroundColor Yellow
    $keyvault = Get-AzKeyVault -VaultName $keyVaultName
    $policy = $keyvault.AccessPolicies.ObjectId -contains $managedIdentityId
    if (!$policy) {
        start-sleep -s 10
    }
    else {
        write-host "key vault access policy propagated $($policy | out-string)" -foregroundColor Green
    }
}

if ($count -ge $maxCount) {
    write-host "key vault access policy did not propagate in time." -foregroundColor Red
    # return
}

write-host "creating key vault certificate in apim"
write-host "New-AzApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apimName" -foregroundColor Cyan
$apiMgmtContext = New-AzApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apimName

write-host "New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier" -foregroundColor Cyan
$keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier

$global:apiMgmtContext = $apiMgmtContext
$global:keyvault = $keyvault
$global:kvcertId = $kvcertId
write-host "New-AzApiManagementCertificate -Context $apiMgmtContext -CertificateId $kvcertId -KeyVault $keyvault" -foregroundColor Cyan
$keyVaultCertificate = New-AzApiManagementCertificate -Context $apiMgmtContext -CertificateId $kvcertId -KeyVault $keyvault

write-host "creating service fabric backend in apim"
$clusterResource = Get-AzResource -Name $clusterName -ResourceType 'Microsoft.ServiceFabric/managedclusters' #-ExpandProperties -ResourceGroupName $resourceGroupName
$cluster = Get-AzServiceFabricManagedCluster -Name $clustername -ResourceGroupName $clusterResource.ResourceGroupName

$backend = @{
    apimName                        = $apimName
    backendName                     = 'ServiceFabricBackend'
    description                     = 'Service Fabric backend'
    clientCertificateThumbprint     = $keyVaultCertificate.Thumbprint
    managementEndpoints             = @("https://$($cluster.Fqdn):$($cluster.HttpGatewayConnectionPort)")
    maxPartitionResolutionRetries   = 5
    serviceFabricManagedClusterFqdn = $cluster.Fqdn
    protocol                        = 'http'
    url                             = $serviceFabricAppUrl
    validateCertificateChain        = $false
    validateCertificateName         = $false
}

write-host "
New-AzResourceGroupDeployment -Name 'apimBackendDeployment' ``
    -ResourceGroupName $resourceGroupName ``
    -TemplateFile $apimBackendTemplate ``
    -TemplateParameterObject $($backend | convertto-json) ``
    -DeploymentDebugLogLevel All ``
    -Verbose ``
    -Force
" -foregroundColor Cyan

New-AzResourceGroupDeployment -Name 'apimBackendDeployment' `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $apimBackendTemplate `
    -TemplateParameterObject $backend `
    -DeploymentDebugLogLevel All `
    -Verbose `
    -Force

write-host "creating api in apim"
$apiId = 'service-fabric-app'
$apiName = 'Service Fabric App'

write-host "
New-AzApiManagementApi -Context $apiMgmtContext ``
    -ApiId $apiId ``
    -Name $apiName ``
    -ServiceUrl 'http://servicefabric' ``
    -Protocols @('http', 'https') ``
    -Path 'api'
" -foregroundColor Cyan

New-AzApiManagementApi -Context $apiMgmtContext `
    -ApiId $apiId `
    -Name $apiName `
    -ServiceUrl 'http://servicefabric' `
    -Protocols @('http', 'https') `
    -Path 'api'

write-host "creating api operation"
$operationId = 'service-fabric-app-operation'
$operationName = 'Service Fabric App Operation'

write-host "
New-AzApiManagementOperation -Context $apiMgmtContext ``
    -ApiId $apiId ``
    -OperationId $operationId ``
    -Name $operationName ``
    -Method 'GET' ``
    -UrlTemplate '$urlTemplate' ``
    -Description ''
" -foregroundColor Cyan

New-AzApiManagementOperation -Context $apiMgmtContext `
    -ApiId $apiId `
    -OperationId $operationId `
    -Name $operationName `
    -Method 'GET' `
    -UrlTemplate $urlTemplate `
    -Description ''

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

write-host "
Set-AzApiManagementPolicy -Context $apiMgmtContext ``
    -ApiId $apiId ``
    -Policy $policyString ``
    -Format 'application/vnd.ms-azure-apim.policy.raw+xml'
" -foregroundColor Cyan

Set-AzApiManagementPolicy -Context $apiMgmtContext `
-ApiId $apiId `
-Policy $policyString `
-Format 'application/vnd.ms-azure-apim.policy.raw+xml'

write-host 'finished' -foregroundColor Green