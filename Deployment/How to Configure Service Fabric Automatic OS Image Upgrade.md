# How to Configure Service Fabric Automatic OS Image Upgrade

This article describes how to configure Service Fabric Automatic OS Image Upgrade for management of Windows OS hotfixes and security updates. This is a best practice for Service Fabric clusters running in production. See [Automatic OS Image Upgrade](https://learn.microsoft.com/azure/service-fabric/how-to-patch-cluster-nodes-windows) for more information including information about Patch Orchestration Application (POA) and how to configure it if unable to use Automatic OS Image Upgrade. Failure to configure Automatic OS Image Upgrade or POA can result in Service Fabric cluster downtime due to default OS hotfix patching configuration which will randomly restart nodes without warning or coordination with Service Fabric Resource Provider.

## Configure 'Silver' or higher node type durability tier

Configure the durability tier for the node type in the cluster resource and the virtual machine scale set resource. The following example shows how to configure the durability tier for the node type 'nt0' to 'Silver' in the cluster resource and the virtual machine scale set resource using an ARM template or using Azure PowerShell. If node type runs only stateless workloads and is 'isStateless' is set to true, then the durability tier can be set to 'Bronze'.

### Service Fabric Managed Clusters

Service fabric managed clusters durability tier is set at  deployment time and cannot be changed after deployment. The default durability tier is 'Silver' for 'Standard' clusters and 'Bronze' for 'Basic' clusters. See [Enable Automatic OS Image Upgrades](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-modify-node-type#enable-automatic-os-image-upgrades) for more information.

### Service Fabric Clusters

> **Note**
> Changing durability tier requires updating both the virtual machine scale set resource and the nested node type array in the cluster resource.

To use Automatic OS Image Upgrade, the node type durability tier must be set to 'Silver' or higher. This is the default and recommended setting for new clusters. Any node type with a durability of 'Bronze' that will use Automatic OS Image Upgrade will need to have durability tier modified and have a minimum of 5 nodes. See [Service Fabric cluster durability tiers](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-capacity#durability-tiers) for more information.

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

## Configuring Automatic OS Image Upgrade

Configure the virtual machine scale set resource to use Automatic OS Image Upgrade. The following example shows how to configure Automatic OS Image Upgrade for node type 'nt0' using an ARM template or using Azure PowerShell.

### Service Fabric Managed Clusters

This option is only available for Service Fabric Managed Clusters on 'Standard' tier.

#### Configure Automatic OS Image Upgrade using ARM template

```diff
"apiVersion": "[variables('sfApiVersion')]",
"type": "Microsoft.ServiceFabric/managedclusters",
"name": "[parameters('clusterName')]",
"location": "[resourcegroup().location]",
"sku": {
    "name" : "[parameters('clusterSku')]"
},
"properties": {
    "dnsName": "[toLower(parameters('clusterName'))]",
    "adminUserName": "[parameters('adminUserName')]",
    "adminPassword": "[parameters('adminPassword')]",
    "allowRdpAccess": true,
    "clientConnectionPort": 19000,
-   "enableAutoOSUpgrade": false,
+   "enableAutoOSUpgrade": true,
    "httpGatewayConnectionPort": 19080,

```

#### Configure Automatic OS Image Upgrade using Azure PowerShell

Uses [Set-AzServiceFabricManagedCluster](https://learn.microsoft.com/powershell/module/az.servicefabric/set-azservicefabricmanagedcluster) cmdlet to configure Automatic OS Image Upgrade for Service Fabric managed clusters.

```powershell
$resourceGroupName = '<resource group name>'
$clusterName = '<cluster name>'
Import-Module -Name Az.ServiceFabric

$managedCluster = Get-AzServiceFabricManagedCluster -ResourceGroupName $resourceGroupName -Name $clusterName
$mangedCluster
$managedCluster.EnableAutomaticOSUpgrade = $true
Set-AzServiceFabricManagedCluster -InputObject $managedCluster -Verbose
```

### Service Fabric Clusters


#### Configure Automatic OS Image Upgrade using ARM template

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

The virtual machine scale set 'version' property in 'imageReference' should be set to 'latest' to enable Automatic OS Image Upgrade. An error similar to below will be returned if 'version' is set to a specifica version.

```diff
"imageReference": {
    "publisher": "MicrosoftWindowsServer",
    "offer": "WindowsServer",
    "sku": "2022-Datacenter",
-   "version": "20348.1726.230505"
+   "version": "latest"
}
```

#### Configure Automatic OS Image Upgrade using Azure PowerShell

The following example shows how to configure Automatic OS Image Upgrade for node type 'nt0' using an ARM template or using Azure PowerShell.

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

There is no management necessary for Automatic OS Image Upgrade for most configurations. For specific settings or troubleshooting, [Azure Virtual Machine Scale Set Automatic OS Image Upgrades](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade) contains configuration details and management of Automatic OS Image Upgrade that is summarized below.

### Enumerate current OS image SKU's available in Azure

New images are applied based on policy settings. The following example shows how to enumerate current OS image SKU's available in Azure to verify if node type is running the latest OS image version. [Example enumerate current OS image SKU's cmdlet output](#example-enumerate-current-os-image-skus-cmdlet-output) below has expected output.

```powershell
Import-Module -Name Az.Compute
Import-Module -Name Az.Resources

$targetImageReference = $latestVersion = [version]::new(0,0,0,0)
$isLatest = $false
$versionsBack = 0
$location = (Get-AzResourceGroup -Name $resourceGroupName).Location
$vmssHistory = @(Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName -OSUpgradeHistory)[0]

if ($vmssHistory) {
    $targetImageReference = $vmssHistory.Properties.TargetImageReference
}
else {
    write-warning "vmssHistory not found"
    $vmssHistory = Get-AzVmss -ResourceGroupName $resourceGroupName -Name $nodeTypeName
    $targetImageReference = $vmssHistory.VirtualMachineProfile.StorageProfile.ImageReference
}

write-host "current running image on node type: " -ForegroundColor Green
$targetImageReference
$publisherName = $targetImageReference.Publisher
$offer = $targetImageReference.Offer
$sku = $targetImageReference.Sku
$runningVersion = $targetImageReference.Version
if($runningVersion -ieq 'latest') {
    write-host "running version is 'latest'"
    $isLatest = $true
    $runningVersion = [version]::new(0,0,0,0)
}

write-host "Get-AzVmImage -Location $location -PublisherName $publisherName -offer $offer -sku $sku" -ForegroundColor Cyan
$images = Get-AzVmImage -Location $location -PublisherName $publisherName -offer $offer -sku $sku
write-host "available versions: " -ForegroundColor Green
$images | format-table -Property Version, Skus, Offer, PublisherName

foreach ($image in $images) {
    if ([version]$latestVersion -gt [version]$runningVersion) { $versionsBack++ }
    if ([version]$latestVersion -lt [version]$image.Version) { $latestVersion = $image.Version }
}

if($isLatest) {
    write-host "published latest version: $latestVersion running version: 'latest'" -ForegroundColor Cyan
}
elseif ($versionsBack -gt 1) {
    write-host "published latest version: $latestVersion is $versionsBack versions newer than current running version: $runningVersion" -ForegroundColor Red
}
elseif ($versionsBack -eq 1) {
    write-host "published latest version: $latestVersion is newer than current running version: $runningVersion" -ForegroundColor Yellow
}
else {
    write-host "current running version: $runningVersion is same or newer than published latest version: $latestVersion" -ForegroundColor Green
}
```

### Review OS image upgrade status

Uses [Get-AzVmssRollingUpgrade](https://learn.microsoft.com/powershell/module/az.compute/get-azvmssrollingupgrade) cmdlet to enumerate current OS image upgrade status. [Example Get-AzVmssRollingUpgrade](#example-Get-AzVmssRollingUpgrade--resourcegroupname-resourcegroupname--name-nodetypename--verbose) below has expected output.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Get-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName `
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

Uses [Start-AzVmssRollingOSUpgrade](https://learn.microsoft.com/powershell/module/az.compute/start-azvmssrollingosupgrade) cmdlet to start OS image upgrade if one is available. Refer to [Enumerate current OS image SKU's available in Azure](#enumerate-current-os-image-skus-available-in-azure) to see if there is a newer OS image version available.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Start-AzVmssRollingOSUpgrade -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $nodeTypeName `
    -Verbose
```

### Stop OS image upgrade

Uses [Stop-AzVmssRollingUpgrade](https://learn.microsoft.com/powershell/module/az.compute/stop-azvmssrollingupgrade) cmdlet to stop OS image upgrade if one is in progress.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Stop-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $nodeTypeName `
    -Force
```

### Rollback OS image upgrade

Uses [Update-AzVmss](https://learn.microsoft.com/powershell/module/az.compute/update-azvmss) cmdlet to disable Automatic OS Image Upgrade and to set older image version. Refer to [Enumerate current OS image SKU's available in Azure](#enumerate-current-os-image-skus-available-in-azure) to enumerate available versions.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
$imageReferenceVersion = '<rollback image version>'
Import-Module -Name Az.Compute

Update-AzVmss -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -AutomaticOSUpgrade $false `
    -EnableAutoUpdate $true `
    -ImageReferenceVersion $imageReferenceVersion `
    -ImageReferencePublisher 'MicrosoftWindowsServer' `
    -ImageReferenceOffer 'WindowsServer' `
    -ImageReferenceSku '2022-Datacenter' `
    -Verbose
``````

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

### Max batch instance percent exceeded before rolling upgrade

Example error:

```powershell
Start-AzVmssRollingOSUpgrade -ResourceGroupName $resourceGroupName -VMScaleSetName nt0
Start-AzVmssRollingOSUpgrade: Long running operation failed with status 'Failed'. Additional Info:'Rolling Upgrade failed due to exceeding the MaxUnhealthyInstancePercent value (defined in the RollingUpgradePolicy) before any batch was attempted. 100% of instances are in an unhealthy state, more than the threshold of 20% configured in the RollingUpgradePolicy. The most impactful error is:  Instance found to be unhealthy or unreachable. For details on rolling upgrades, use http://aka.ms/AzureVMSSRollingUpgrade'
ErrorCode: MaxUnhealthyInstancePercentExceededBeforeRollingUpgrade
ErrorMessage: Rolling Upgrade failed due to exceeding the MaxUnhealthyInstancePercent value (defined in the RollingUpgradePolicy) before any batch was attempted. 100% of instances are in an unhealthy state, more than the threshold of 20% configured in the RollingUpgradePolicy. The most impactful error is:  Instance found to be unhealthy or unreachable. For details on rolling upgrades, use http://aka.ms/AzureVMSSRollingUpgrade
ErrorTarget: 
StartTime: 7/12/2023 4:40:32 PM
EndTime: 7/12/2023 4:40:51 PM
OperationID: 40fb67ad-efa4-478c-bf4c-71806d3ba965
Status: Failed
```

Example error:

```powershell
Get-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName -VMScaleSetName nt0 | ConvertTo-Json -depth 5
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
    "Code": "Faulted",
    "StartTime": "2023-07-12T20:20:13.145292Z",
    "LastAction": "Start",
    "LastActionTime": "2023-07-12T20:20:13.145292Z"
  },
  "Progress": {
    "SuccessfulInstanceCount": 0,
    "FailedInstanceCount": 0,
    "InProgressInstanceCount": 0,
    "PendingInstanceCount": 0
  },
  "Error": {
    "Details": [
      {
        "Code": "RollingUpgradeInstanceUnhealthyError",
        "Target": "nt1/virtualMachines/0",
        "Message": "Instance found to be unhealthy or unreachable."
      },
      {
        "Code": "RollingUpgradeInstanceUnhealthyError",
        "Target": "nt1/virtualMachines/1",
        "Message": "Instance found to be unhealthy or unreachable."
      },
      {
        "Code": "RollingUpgradeInstanceUnhealthyError",
        "Target": "nt1/virtualMachines/2",
        "Message": "Instance found to be unhealthy or unreachable."
      }
    ],
    "Innererror": null,
    "Code": "MaxUnhealthyInstancePercentExceededBeforeRollingUpgrade",
    "Target": null,
    "Message": "Rolling Upgrade failed due to exceeding the MaxUnhealthyInstancePercent value (defined in the RollingUpgradePolicy) before any batch was attempted. 100% of instances are in an unhealthy state, more than the threshold of 20% configured in the RollingUpgradePolicy. The most impactful error is:  Instance found to be unhealthy or unreachable. For details on rolling upgrades, use http://aka.ms/AzureVMSSRollingUpgrade"
  },
  "Id": null,
  "Name": null,
  "Type": "Microsoft.Compute/virtualMachineScaleSets/rollingUpgrades",
  "Location": "eastus",
  "Tags": {}
}
```

Resolution:

Verify that the node type has at least 5 nodes and that the node type durability is set to 'Silver' or higher. See [Configure 'Silver' or higher node type durability tier](#configure-silver-or-higher-node-type-durability-tier) for more information.

## Examples

### Example Get-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName -Name $nodeTypeName -Verbose

> **Note**
> RunningStatus information is last time a rolling upgrade was started but not necessarily last time an image was upgraded. Use [Example Get-AzVmss](#example-get-azvmss--resourcegroupname-resourcegroupname--name-nodetypename--osupgradehistory) to get last time an image was upgraded.

```powershell
Get-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName -Name $nodeTypeName | ConvertTo-Json
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
> An empty result can indicate that node type is not configured for Automatic OS Image Upgrade or an upgrade has not taken place yet.

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

### Example enumerate current OS image SKU's cmdlet output

```powershell
current running image on node type:
Publisher               : MicrosoftWindowsServer
Offer                   : WindowsServer
Sku                     : 2022-Datacenter
Version                 : 20348.1850.230707
ExactVersion            :
SharedGalleryImageId    :
CommunityGalleryImageId :
Id                      :

Get-AzVmImage -Location eastus -PublisherName MicrosoftWindowsServer -offer WindowsServer -sku 2022-Datacenter
available versions: 

Version           Skus            Offer         PublisherName
-------           ----            -----         -------------
20348.1006.220908 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1129.221007 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1131.221014 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1249.221105 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1366.221207 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1487.230106 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1547.230207 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1607.230310 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1668.230404 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1726.230505 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1787.230607 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1787.230621 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.1850.230707 2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.768.220609  2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.825.220704  2022-Datacenter WindowsServer MicrosoftWindowsServer
20348.887.220806  2022-Datacenter WindowsServer MicrosoftWindowsServer

current running version: 20348.1850.230707 is same or newer than published latest version: 20348.1850.230707
```
