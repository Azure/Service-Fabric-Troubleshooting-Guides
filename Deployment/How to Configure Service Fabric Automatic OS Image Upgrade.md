# How to Configure Service Fabric Automatic OS Image Upgrade

This article describes how to configure Service Fabric automatic OS image upgrade for management of Windows OS hotfixes and security updates. This is a best practice for Service Fabric clusters running in production. See [Automatic OS image upgrade](https://learn.microsoft.com/azure/service-fabric/how-to-patch-cluster-nodes-windows) for more information including information about Patch Orchestration Application (POA) and how to configure it if unable to use automatic OS image upgrade. Failure to configure automatic OS image upgrade or POA can result in Service Fabric cluster downtime due to default OS hotfix patching configuration which will randomly restart nodes without warning or coordination with Service Fabric Resource Provider.

## Configure 'Silver' or higher node type durability tier

Configure the durability tier for the node type in the cluster resource and the virtual machine scale set resource. The following example shows how to configure the durability tier for the node type 'nt0' to 'Silver' in the cluster resource and the virtual machine scale set resource using an ARM template or using Azure PowerShell.

### Service Fabric Managed Clusters

Service fabric managed clusters durability tier is set at  deployment time and cannot be changed after deployment. The default durability tier is 'Silver' for 'Standard' clusters and 'Bronze' for 'Basic' clusters. See [Service Fabric managed clusters](https://learn.microsoft.com/azure/service-fabric/service-fabric-managed-cluster-overview) for more information.

### Service Fabric Clusters

> **Note**
> Changing durability tier requires updating both the virtual machine scale set resource and the nested node type array in the cluster resource.

To use automatic OS image upgrade, the node type durability tier must be set to 'Silver' or higher. This is the default and recommended setting for new clusters. Any node type with a durability of 'Bronze' that will use automatic OS image upgrade will need to have durability tier modified and have a minimum of 5 nodes. See [Service Fabric cluster durability tiers](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-capacity#durability-tiers) for more information.

#### Configure durability tier using ARM template

Microsoft.ServiceFabric/clusters/nodeTypes resource

```diff
{
    "type": "Microsoft.ServiceFabric/clusters",
    "apiVersion": "2021-06-01",
    "name": "[parameters('cluster_name')]",
    "properties": {
    "managementEndpoint": "[concat('https://', parameters('cluster_name'), '.eastus.cloudapp.azure.com:19080')]",
    "certificate": {},
    "clientCertificateThumbprints": [],
    "clientCertificateCommonNames": [],
    "fabricSettings": [],
    "vmImage": "Windows",
    "reliabilityLevel": "Silver",
    "nodeTypes": [
        {
        "name": "nt0",
        "clientConnectionEndpointPort": 19000,
        "httpGatewayEndpointPort": 19080,
        "applicationPorts": {
            "startPort": 20000,
            "endPort": 30000
        },
        "ephemeralPorts": {
            "startPort": 49152,
            "endPort": 65534
        },
        "isPrimary": true,
-        "durabilityLevel": "Bronze",
+        "durabilityLevel": "Silver",
        "vmInstanceCount": 5,
        "isStateless": false
        },
...
```

Microsoft.Compute/virtualMachineScaleSets/extensions resource

```diff
{
    "apiVersion": "2022-11-01",
    "name": "[concat(parameters('vmNodeType0Name'), '/ServiceFabricNode')]",
    "type": "Microsoft.Compute/virtualMachineScaleSets/extensions",
    "location": "[parameters('location')]",
    "dependsOn": [
        "[concat('Microsoft.Compute/virtualMachineScaleSets/', parameters('vmNodeType0Name'))]"
    ],
    "properties": {
        "publisher": "Microsoft.Azure.ServiceFabric",
        "type": "ServiceFabricNode",
        "typeHandlerVersion": "1.0",
        "autoUpgradeMinorVersion": true,
        "settings": {
            "clusterEndpoint": "[reference(resourceId('Microsoft.ServiceFabric/clusters', parameters('clusterName')), '2018-02-01-preview').properties.clusterEndpoint]",
            "nodeTypeRef": "[parameters('nodeTypeName')]",
            "dataPath": "D:\\SvcFab",
-            "durabilityLevel": "Bronze",
+            "durabilityLevel": "Silver",
            "certificate": {
                "thumbprint": "[parameters('certificateThumbprint')]",
                "x509StoreName": "[parameters('certificateStoreValue')]"
            }
        },
        "protectedSettings": {
            "StorageAccountKey1": "[parameters('storageAccountKey1')]",
            "StorageAccountKey2": "[parameters('storageAccountKey2')]"
        }
    }
}
```


#### Configure durability tier using Azure PowerShell

Uses [Update-AzServiceFabricDurability](https://learn.microsoft.com/powershell/module/az.servicefabric/update-azservicefabricdurability) cmdlet to update the durability tier for the node type in the cluster resource.

```powershell

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
$nodeTypeDurability = 'Silver'
$clusterName = $resourceGroupName
Import-Module -Name Az.ServiceFabric

Update-AzServiceFabricDurability -ResourceGroupName $resourceGroupName `
    -Name $clusterName `
    -NodeType $nodeTypeName `
    -DurabilityLevel $nodeTypeDurability `
    -Verbose
```

#### Update the virtual machine scale set using Set-AzResource

Uses [Set-AzResource](https://learn.microsoft.com/powershell/module/az.resources/set-azresource) cmdlet to update the durability tier for the node type in the virtual machine scale set resource.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
$nodeTypeDurability = 'Silver'
Import-Module -Name Az.Resources

$vmss = Get-AzResource -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -ResourceType 'Microsoft.Compute/virtualMachineScaleSets' `
    -ExpandProperties

$sfExtension = $vmss.Properties.virtualMachineProfile.extensionProfile.extensions `
    | Where-Object {$psitem.properties.publisher -ieq 'Microsoft.Azure.ServiceFabric'}
$sfExtension.properties.settings.durabilityLevel = $nodeTypeDurability

$vmss | Set-AzResource -Verbose -Force
```

## Configuring automatic OS image upgrade

### Service Fabric Managed Clusters


#### Configure automatic OS image upgrade using ARM template


#### Configure automatic OS image upgrade using Azure PowerShell

```powershell
```


### Service Fabric Clusters


#### Configure automatic OS image upgrade using ARM template

Add 'automaticOSUpgradePolicy' to 'upgradePolicy' and disable 'enableAutomaticUpdates' in 'windowsConfiguration' in the virtual machine scale set resource.

```diff
{
    "apiVersion": "[variables('vmssApiVersion')]",
    "type": "Microsoft.Compute/virtualMachineScaleSets",
    "name": "[parameters('vmNodeType0Name')]",
    "location": "[resourceGroup().location]",
    "dependsOn": [
    ],
    "properties": {
        "overprovision": "[parameters('overProvision')]",
        "upgradePolicy": {
-           "mode": "Automatic"
+           "mode": "Automatic",
+           "automaticOSUpgradePolicy": {
+              "enableAutomaticOSUpgrade": true
+              "disableAutomaticRollback": false
+           }
        },
        "virtualMachineProfile": {
            "storageProfile": {
                "osDisk": {
                    "caching": "ReadWrite",
                    "createOption": "FromImage",
                    "diskSizeGB": "[parameters('osDiskSizeGB')]"
                },
                "imageReference": {
                    "publisher": "[parameters('imagePublisher')]",
                    "offer": "[parameters('imageOffer')]",
                    "sku": "[parameters('imageSku')]",
                    "version": "[parameters('imageVersion')]"
                }
            },
            "osProfile": {
                "computerNamePrefix": "[parameters('vmNodeType0Name')]",
                "adminUsername": "[parameters('adminUserName')]",
                "adminPassword": "[parameters('adminPassword')]",
                "windowsConfiguration": {
-                   "enableAutomaticUpdates": true,
+                   "enableAutomaticUpdates": false,
                    "provisionVMAgent": true,
                    "patchSettings": {
                        "patchMode": "AutomaticByOS"
                    }
                }
            },
...
```

The virtual machine scale set 'version' property in 'imageReference' should be set to 'latest' to enable automatic OS image upgrade. An error similar to below will be returned if 'version' is set to a specifica version.

```diff
"imageReference": {
    "publisher": "MicrosoftWindowsServer",
    "offer": "WindowsServer",
    "sku": "2022-Datacenter",
-   "version": "20348.1726.230505"
+   "version": "latest"
}
```

#### Configure automatic OS image upgrade using Azure PowerShell

The following example shows how to configure automatic OS image upgrade for node type 'nt0' using an ARM template or using Azure PowerShell.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Update-AzVmss -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -AutomaticOSUpgrade $true `
    -EnableAutoUpdate $false `
    -Verbose
```

## Manage OS image upgrade

### Enumerate current OS image SKU's available in Azure

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute
Import-Module -Name Az.Resources

$latestVersion = $null;
$targetImageReference = $null
$location = (Get-AzResourceGroup -Name $resourceGroupName).Location
$vmssHistory = Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName -OSUpgradeHistory

if ($vmssHistory) {
    $targetImageReference = $vmssHistory.Properties.TargetImageReference
}
else {
    write-warning "vmssHistory not found"
    $vmssHistory = Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName
    $targetImageReference = $vmssHistory.VirtualMachineProfile.StorageProfile.ImageReference
}

$publisherName = $targetImageReference.Publisher
$offer = $targetImageReference.Offer
$sku = $targetImageReference.Sku
$runningVersion = $targetImageReference.Version

write-host "Get-AzVmImage -Location $location -PublisherName $publisherName -offer $offer -sku $sku"
$images = Get-AzVmImage -Location $location -PublisherName $publisherName -offer $offer -sku $sku

foreach ($image in $images) {
    if ([version]$image.Version -gt [version]$runningVersion) { $latestVersion = $image.Version }
}

if ($latestVersion -gt $currentVersion) {
    write-host "latest version published: $latestVersion is newer than current running version: $runningVersion" -ForegroundColor Green
}
else {
    write-host "current running version: $runningVersion is same or newer than latest version: $latestVersion" -ForegroundColor Green
}
```

### Review OS image upgrade status

Uses [Get-AzVmssRollingUpgradeStatus](https://learn.microsoft.com/powershell/module/az.compute/get-azvmssrollingupgradestatus) cmdlet to enumerate current OS image upgrade status. [Example Get-AzVmssRollingUpgradeStatus](#example-get-azvmssrollingupgradestatus--resourcegroupname-resourcegroupname--name-nodetypename--verbose) below has expected output.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Get-AzVmssRollingUpgradeStatus -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -Verbose
```
### Review OS image upgrade history

Uses [Get-AzVmss](https://learn.microsoft.com/powershell/module/az.compute/get-azvmss) cmdlet to enumerate OS image upgrade history. [Example Get-AzVmss](#example-get-azvmss--resourcegroupname-resourcegroupname--name-nodetypename--osupgradehistory) below has expected output.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Get-AzVmss -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -OSUpgradeHistory `
    -Verbose
```

### Configure Rolling Upgrade Policy

Additional configuration for Automatic OS Upgrade can be configured using [Set-AzVmssRollingUpgradePolicy](https://learn.microsoft.com/powershell/module/az.compute/set-azvmssrollingupgradepolicy?view=azps-10.1.0) cmdlet. The following example shows how to configure rolling upgrade policy for node type 'nt0' using an ARM template or using Azure PowerShell.

```diff
"properties": {
    "singlePlacementGroup": true,
    "upgradePolicy": {
        "mode": "Automatic",
+       "rollingUpgradePolicy": {
+           "maxBatchInstancePercent": 20,
+           "maxUnhealthyInstancePercent": 20,
+           "maxUnhealthyUpgradedInstancePercent": 20,
+           "pauseTimeBetweenBatches": "PT0S"
+     },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "disableAutomaticRollback": false
      }
    },
```

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
$pauseTimeSeconds = 'PT0S' # ISO 8601 duration format
$createNewInstancesInsteadOfUpgrading = $false
Import-Module -Name Az.Compute

$vmss = Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName

Set-AzVmssRollingUpgradePolicy -VirtualMachineScaleSet $vmss `
    -MaxBatchInstancePercent 20 `
    -MaxUnhealthyInstancePercent 20 `
    -MaxUnhealthyUpgradedInstancePercent 20 `
    -PauseTimeBetweenBatches $pauseTimeSeconds `
    -PrioritizeUnhealthyInstances $true `
    -EnableCrossZoneUpgrade $true `
    -MaxSurge $createNewInstancesInsteadOfUpgrading `
    -Verbose
```

### Manual Upgrade OS image

Uses [Start-AzVmssRollingOSUpgrade](https://learn.microsoft.com/en-us/powershell/module/az.compute/start-azvmssrollingosupgrade) cmdlet to start OS image upgrade if one is available. Refer to [Enumerate current OS image SKU's available in Azure](#enumerate-current-os-image-skus-available-in-azure) to see if there is a newer OS image version available.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Start-AzVmssRollingOSUpgrade -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $nodeTypeName `
    -Verbose
```

### Stop OS image upgrade

Uses [Stop-AzVmssRollingUpgrade](https://learn.microsoft.com/en-us/powershell/module/az.compute/stop-azvmssrollingupgrade) cmdlet to stop OS image upgrade if one is in progress.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Stop-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $nodeTypeName `
    -Force
```

## Troubleshooting

### Durability mismatch

Example error:

```powershell
$vmss | Set-AzResource   

Confirm
Set-AzResource: OperationNotAllowed : Durability Mismatch Detected for NodeType nt0. VMSS Durability Silver does not match the current SFRP NodeType durability level Bronze
```

Resolution:

Update SFRP node type durability level to match VMSS durability level.

### The OS Rolling Upgrade API cannot be used on a Virtual Machine Scale Set unless the Virtual Machine Scale Set has some unprotected instances which have imageReference.version set to latest

```powershell
Start-AzVmssRollingOsUpgrade -ResourceGroupName $resourceGroupName -VMScaleSetName nt0 | ConvertTo-Json
Start-AzVmssRollingOSUpgrade: The OS Rolling Upgrade API cannot be used on a Virtual Machine Scale Set unless the Virtual Machine Scale Set has some unprotected instances which have imageReference.version set to latest.
ErrorCode: OperationNotAllowed
ErrorMessage: The OS Rolling Upgrade API cannot be used on a Virtual Machine Scale Set unless the Virtual Machine Scale Set has some unprotected instances which have imageReference.version set to latest.
ErrorTarget: 
StatusCode: 409
ReasonPhrase: Conflict
OperationID : 90368558-b15f-4aad-aae9-38de2b679f1b
```

Resolution:

Update VMSS to use 'latest' as the image version.

## Examples

### Example Get-AzVmssRollingUpgradeStatus -ResourceGroupName $resourceGroupName -Name $nodeTypeName -Verbose

> **Note**
> RunningStatus information is last time a rolling upgrade was started but not necessarily last time an image was upgraded. Use [Example Get-AzVmss](#example-get-azvmss--resourcegroupname-resourcegroupname--name-nodetypename--osupgradehistory) to get last time an image was upgraded.

```powershell
Get-AzVmssRollingUpgradeStatus -ResourceGroupName $resourceGroupName -Name $nodeTypeName | ConvertTo-Json
{
  "Policy": {
    "MaxBatchInstancePercent": 20,
    "MaxUnhealthyInstancePercent": 20,
    "MaxUnhealthyUpgradedInstancePercent": 20,
    "PauseTimeBetweenBatches": "PT0S",
    "EnableCrossZoneUpgrade": null,
    "PrioritizeUnhealthyInstances": null,
    "RollbackFailedInstancesOnPolicyBreach": false,
    "MaxSurge": false
  },
  "RunningStatus": {
    "Code": "Completed",
    "StartTime": "2023-06-30T19:46:17.2677469Z",
    "LastAction": "Start",
    "LastActionTime": "2023-06-30T19:46:17.2208724Z"
  },
  "Progress": {
    "SuccessfulInstanceCount": 0,
    "FailedInstanceCount": 0,
    "InProgressInstanceCount": 0,
    "PendingInstanceCount": 0
  },
  "Error": null,
  "Id": null,
  "Name": null,
  "Type": "Microsoft.Compute/virtualMachineScaleSets/rollingUpgrades",
  "Location": "eastus",
  "Tags": {}
}
```

### Example Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName -OSUpgradeHistory

> **Note**
> An empty result can indicate that node type is not configured for automatic os image upgrade or an upgrade has not taken place yet.

```powershell
Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName -OSUpgradeHistory | ConvertTo-Json
{
  "Properties": {
    "RunningStatus": {
      "Code": "Completed",
      "StartTime": "2023-06-30T19:46:17.2677469Z",
      "EndTime": null
    },
    "Progress": {
      "SuccessfulInstanceCount": 0,
      "FailedInstanceCount": 0,
      "InProgressInstanceCount": 0,
      "PendingInstanceCount": 0
    },
    "Error": null,
    "StartedBy": "Platform",
    "TargetImageReference": {
      "Publisher": "MicrosoftWindowsServer",
      "Offer": "WindowsServer",
      "Sku": "2022-Datacenter",
      "Version": "20348.1787.230621",
      "ExactVersion": null,
      "SharedGalleryImageId": null,
      "CommunityGalleryImageId": null,
      "Id": null
    },
    "RollbackInfo": {
      "SuccessfullyRolledbackInstanceCount": 0,
      "FailedRolledbackInstanceCount": 0,
      "RollbackError": null
    }
  },
  "Type": "Microsoft.Compute/virtualMachineScaleSets/rollingUpgrades",
  "Location": "eastus"
}
```

### Example Start-AzVmssRollingOSUpgrade -ResourceGroupName $resourceGroupName -VMScaleSetName $nodeTypeName -Verbose

> **Note**
> A result similar to below will always be returned regardless of whether there is a newer OS image version available or not.


```powershell
Start-AzVmssRollingOsUpgrade -ResourceGroupName $resourceGroupName -VMScaleSetName $nodeTypeName | ConvertTo-Json
{
  "Name": "6dd0212d-ff35-4dce-b77e-999a57c1534e",
  "StartTime": "2023-07-11T19:34:57.7803755-04:00",
  "EndTime": "2023-07-11T19:35:28.2994743-04:00",
  "Status": "Succeeded",
  "Error": null
}
```