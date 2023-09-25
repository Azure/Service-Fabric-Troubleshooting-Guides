<#
.SYNOPSIS
    This script will check the current and latest versions of the Azure VM Image SKU for a given node type in a given resource group.

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
invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/enumerate-vmss-image-sku.ps1" -outFile "$pwd\enumerate-vmss-image-sku.ps1";
.\enumerate-vmss-image-sku.ps1 -resourceGroupName <resource group name> -nodeTypeName <node type name>

#>

param(
    [Parameter(Mandatory = $true)]
    $resourceGroupName,
    $clusterName = $resourceGroupName,
    $nodeTypeName,
    $instanceId = 0
)

Import-Module -Name Az.Compute
Import-Module -Name Az.Resources

function main() {
    $targetImageReference = $latestVersion = [version]::new(0, 0, 0, 0)
    $isLatest = $false
    $versionsBack = 0
    $location = (Get-AzResourceGroup -Name $resourceGroupName).Location

    $cluster = Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.ServiceFabric/clusters -ResourceName $clusterName -ErrorAction SilentlyContinue

    if (!$cluster) {
        $cluster = Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.ServiceFabric/managedclusters -ResourceName $clusterName
        $resourceGroupName = "SFC_$($cluster.Properties.clusterid)"
    } 
    if (!$cluster) {
        write-error "cluster not found. specify -clusterName`r`n$($error | out-string)"
        exit
    }

    if (!$nodeTypeName) {
        write-host "node type name not specified. using first node type name: $($cluster.Properties.nodeTypes[0].name)" -ForegroundColor Yellow
        $nodeTypeName = $cluster.Properties.nodeTypes[0].name
    }

    $vmssHistory = @(Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName -OSUpgradeHistory)[0]

    if ($vmssHistory) {
        $targetImageReference = $vmssHistory.Properties.TargetImageReference
    }
    else {
        write-warning "vmssHistory not found. checking current image reference"
        $vmssHistory = Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName
        $targetImageReference = $vmssHistory.VirtualMachineProfile.StorageProfile.ImageReference
    }

    $targetImageReference = $targetImageReference | convertto-json | convertfrom-json

    if (!$targetImageReference) {
        write-warning "vmssHistory not found. checking instance $instanceId"
        $vmssVmInstance = get-azvmssvm -ResourceGroupName $resourceGroupName -VMScaleSetName $nodeTypeName -InstanceId $instanceId
        $targetImageReference = $vmssVmInstance.StorageProfile.ImageReference
    }
    elseif (!$targetImageReference.ExactVersion) {
        write-warning "targetImageReference ExactVersion not found. checking instance $instanceId"
        $vmssVmInstance = get-azvmssvm -ResourceGroupName $resourceGroupName -VMScaleSetName $nodeTypeName -InstanceId $instanceId
        $targetImageReference.ExactVersion = @($vmssVmInstance.StorageProfile.ImageReference.ExactVersion)[0]
    }

    if (!$targetImageReference) {
        write-error "current vm image version not found. exiting"
        #return
    }
    else {
        write-host "current running image on node type: " -ForegroundColor Green
        $targetImageReference
        $publisherName = $targetImageReference.Publisher
        $offer = $targetImageReference.Offer
        $sku = $targetImageReference.Sku
        $runningVersion = ($targetImageReference.ExactVersion, $targetImageReference.Version | select-object -first 1)
        if ($runningVersion -ieq 'latest') {
            write-host "running version is 'latest'"
            $isLatest = $true
            $runningVersion = [version]::new(0, 0, 0, 0)
        }    
    }
    
    write-host "Get-AzVmImage -Location $location -PublisherName $publisherName -offer $offer -sku $sku" -ForegroundColor Cyan
    $imageSkus = Get-AzVmImage -Location $location -PublisherName $publisherName -offer $offer -sku $sku
    $orderedSkus = [collections.generic.list[version]]::new()

    foreach ($image in $imageSkus) {
        [void]$orderedSkus.Add([version]::new($image.Version)) 
    }

    $orderedSkus = $orderedSkus | Sort-Object
    write-host "available versions: " -ForegroundColor Green
    $orderedSkus.foreach{ $psitem.ToString() }

    foreach ($sku in $orderedSkus) {
        if ([version]$sku -gt [version]$runningVersion) { $versionsBack++ }
        if ([version]$latestVersion -lt [version]$sku) { $latestVersion = $sku }
    }

    if ($isLatest) {
        write-host "published latest version: $latestVersion running version: 'latest'" -ForegroundColor Cyan
    }
    elseif ($versionsBack -gt 1) {
        write-host "published latest version: $latestVersion is $versionsBack versions newer than current running version: $runningVersion" -ForegroundColor Red
    }
    elseif ($versionsBack -eq 1) {
        write-host "published latest version: $latestVersion is one version newer than current running version: $runningVersion" -ForegroundColor Yellow
    }
    else {
        write-host "current running version: $runningVersion is same or newer than published latest version: $latestVersion" -ForegroundColor Green
    }
}

main