# How to Configure Service Fabric Cluster Automatic OS Image Upgrade

This article describes the best practice of configuring Service Fabric cluster Automatic OS Image Upgrade for management of Windows OS hotfixes and security updates. See [Automatic OS Image Upgrade](https://learn.microsoft.com/azure/service-fabric/how-to-patch-cluster-nodes-windows) for more information including information about Patch Orchestration Application (POA) and configuration if unable to use Automatic OS Image Upgrade. Failure to configure Automatic OS Image Upgrade or POA can result in Service Fabric cluster downtime due to default OS hotfix patching configuration which will randomly restart nodes without warning or coordination with Service Fabric Resource Provider.

### Service Fabric Managed Clusters

Service Fabric Managed clusters ... TODO [How to Configure Service Fabric Managed Cluster Automatic OS Image Upgrade](./How%20to%20Configure%20Service%20Fabric%20Managed%20Cluster%20Automatic%20OS%20Image%20Upgrade.md)


## Configure 'Silver' or higher node type durability tier

Configure the durability tier and Service Fabric extension typeHandlerVersion for the node type in the cluster resource and the virtual machine scale set resource. The following examples show how to configure the durability tier for node type 'nt0' to 'Silver' in the cluster resource and the virtual machine scale set resource using an ARM template or using Azure PowerShell.

> **Note**
> Changing durability tier requires updating both the virtual machine scale set resource and the nested node type array in the cluster resource.

To use Automatic OS Image Upgrade, the node type durability tier must be set to 'Silver' or higher and Service Fabric extension 'typeHandlerVersion' must be at least '1.1'. This is the default and recommended setting for new clusters. There is one uncommon scenario where if the node type runs only stateless workloads and is 'isStateless' is set to true, then the durability tier can be set to 'Bronze'. Any node type with a durability of 'Bronze' that will use Automatic OS Image Upgrade will need to have durability tier modified and have a minimum of 5 nodes. See [Service Fabric cluster durability tiers](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-capacity#durability-tiers) for more information.

#### Configure durability tier and typeHandlerVersion using ARM template

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
-        "typeHandlerVersion": "1.0",
+        "typeHandlerVersion": "1.1",
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

#### Configure durability tier and typeHandlerVersion using Azure PowerShell

For Service Fabric clusters only, use [Update-AzServiceFabricDurability](https://learn.microsoft.com/powershell/module/az.servicefabric/update-azservicefabricdurability) cmdlet to update the durability tier for the node type in the cluster resource.

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

Use [Set-AzResource](https://learn.microsoft.com/powershell/module/az.resources/set-azresource) cmdlet to update the durability tier for the node type in the virtual machine scale set resource.

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
$sfExtension.properties.typeHandlerVersion = '1.1'
$vmss | Set-AzResource -Verbose -Force
```

## Configuring Automatic OS Image Upgrade

Configure the virtual machine scale set resource to use Automatic OS Image Upgrade. The following example shows how to configure Automatic OS Image Upgrade for node type 'nt0' using an ARM template or using Azure PowerShell.


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
+              "useRollingUpgradePolicy": false
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

The virtual machine scale set 'version' property in 'imageReference' should be set to 'latest' to enable Automatic OS Image Upgrade. An error similar to below will be returned if 'version' is set to a specific version.

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

The following example shows how to configure Automatic OS Image Upgrade for node type 'nt0' using an ARM template or using Azure PowerShell. Uses [Update-AzVmss](https://learn.microsoft.com/powershell/module/az.compute/update-azvmss) cmdlet to configure Automatic OS Image Upgrade for Service Fabric clusters.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Update-AzVmss -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -AutomaticOSUpgrade $true `
    -EnableAutomaticUpdate $false `
    -Verbose
```

## Manage OS Image Upgrade

There is no management necessary for Automatic OS Image Upgrade for most configurations. For specific settings or troubleshooting, [Azure Virtual Machine Scale Set Automatic OS Image Upgrades](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade) contains configuration details and management of Automatic OS Image Upgrade that is summarized below. 

If more control is required for image releases than what is available through these configuration settings, Automatic OS Image Upgrade supports the use of custom images. Using custom images from a shared compute gallery provides additional configuration such as image expiration dates and 'latest' version. See [Tutorial: Create and use a custom image for Virtual Machine Scale Sets with Azure PowerShell](https://learn.microsoft.com/azure/virtual-machine-scale-sets/tutorial-use-custom-image-powershell) for this process.

### Automatic OS Upgrade Process

From [Azure Virtual Machine Scale Set Automatic OS Image Upgrades](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade), below is the default process Automatic OS Image Upgrade uses for scale sets. To configure additional checks for successful upgrade, only [Application Health extension](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension) can be used for Service Fabric clusters. In addition, for Service Fabric clusters, only the 'Bronze' durability *and* 'Stateless' Nodetype be used with Application Health extension. See [Using Application Health Probes](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade#using-application-health-probes) and [Service Fabric requirements](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade#service-fabric-requirements).

The region of a scale set becomes eligible to get image upgrades either through the availability-first process for platform images or replicating new custom image versions for Share Image Gallery. The image upgrade is then applied to an individual scale set in a batched manner as follows:

1. Before you begin the upgrade process, the orchestrator will ensure that no more than 20% of instances in the entire scale set are unhealthy (for any reason).
1. The upgrade orchestrator identifies the batch of VM instances to upgrade, with any one batch having a maximum of 20% of the total instance count, subject to a minimum batch size of one virtual machine. There is no minimum scale set size requirement and scale sets with 5 or fewer instances will have 1 VM per upgrade batch (minimum batch size).
1. The OS disk of every VM in the selected upgrade batch is replaced with a new OS disk created from the latest image. All specified extensions and configurations in the scale set model are applied to the upgraded instance.
1. For clusters with 'Stateless' node types and 'Bronze' durability with configured Application Health extension, the upgrade waits up to 5 minutes for the instance to become healthy, before moving on to upgrade the next batch. If an instance does not recover its health in 5 minutes after an upgrade, then by default the previous OS disk for the instance is restored.
1. The upgrade orchestrator also tracks the percentage of instances that become unhealthy post an upgrade. The upgrade will stop if more than 20% of upgraded instances become unhealthy during the upgrade process.
1. The above process continues until all instances in the scale set have been upgraded.

### Scheduling OS Image Upgrade with Maintenance Control

Azure Service Fabric clusters support [Maintenance Control](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-maintenance-control) which allows configuration of when maintenance is performed on the virtual machine scale set including Automatic OS Image Upgrade.

> **Note**
> Maintenance Control requires a schedule with minimum settings of daily schedule with at least a 5 hour window. Updates not completed in the provided window will resume during next window.

Azure Service Fabric Managed Clusters support for Maintenance Control is currently in preview. See [MaintenanceControl](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-maintenance-control) for configuration and support information as not all regions are currently supported.

### Enumerate current OS image SKU's available in Azure

New images are applied based on policy settings. [enumerate-vmss-image-sku.ps1](../Scripts/enumerate-vmss-image-sku.ps1) enumerates current OS image SKU's available in Azure to verify if node type is running the latest OS image version. [Example enumerate current OS image SKU's cmdlet output](#example-enumerate-current-os-image-skus-cmdlet-output) below has expected output. As soon as the PowerShell commands are executed, the rollback will start.

### Review OS image upgrade status

For Service Fabric clusters only, use [Get-AzVmssRollingUpgrade](https://learn.microsoft.com/powershell/module/az.compute/get-azvmssrollingupgrade) cmdlet to enumerate current OS image upgrade status. [Example Get-AzVmssRollingUpgrade](#example-Get-AzVmssRollingUpgrade--resourcegroupname-resourcegroupname--name-nodetypename--verbose) below has expected output.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Get-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -Verbose
```

### Review OS image upgrade history

For Service Fabric clusters only, use [Get-AzVmss](https://learn.microsoft.com/powershell/module/az.compute/get-azvmss) cmdlet to enumerate OS image upgrade history. [Example Get-AzVmss](#example-get-azvmss--resourcegroupname-resourcegroupname--name-nodetypename--osupgradehistory) below has expected output.

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
-       "useRollingUpgradePolicy": false
+       "useRollingUpgradePolicy": true
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

For Service Fabric clusters only, use [Start-AzVmssRollingOSUpgrade](https://learn.microsoft.com/powershell/module/az.compute/start-azvmssrollingosupgrade) cmdlet to start OS image upgrade if one is available. Refer to [Enumerate current OS image SKU's available in Azure](#enumerate-current-os-image-skus-available-in-azure) to see if there is a newer OS image version available.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Start-AzVmssRollingOSUpgrade -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $nodeTypeName `
    -Verbose
```

### Stop OS image upgrade

For Service Fabric clusters only, use [Stop-AzVmssRollingUpgrade](https://learn.microsoft.com/powershell/module/az.compute/stop-azvmssrollingupgrade) cmdlet to stop OS image upgrade if one is in progress.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
Import-Module -Name Az.Compute

Stop-AzVmssRollingUpgrade -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $nodeTypeName `
    -Force
```

### Rollback OS image upgrade

For Service Fabric clusters only, use [Update-AzVmss](https://learn.microsoft.com/powershell/module/az.compute/update-azvmss) cmdlet to disable Automatic OS Image Upgrade and to set older image version. Refer to [Enumerate current OS image SKU's available in Azure](#enumerate-current-os-image-skus-available-in-azure) to enumerate available versions.

```powershell
$resourceGroupName = '<resource group name>'
$nodeTypeName = '<node type name>'
$imageReferenceVersion = '<rollback image version>'
Import-Module -Name Az.Compute

Update-AzVmss -ResourceGroupName $resourceGroupName `
    -Name $nodeTypeName `
    -AutomaticOSUpgrade $false `
    -EnableAutomaticUpdate $true `
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
Version                 : latest
ExactVersion            : 
SharedGalleryImageId    : 
CommunityGalleryImageId : 
Id                      : 

running version is 'latest'
Get-AzVmImage -Location eastus -PublisherName MicrosoftWindowsServer -offer WindowsServer -sku 2022-Datacenter
available versions: 
20348.825.220704
20348.887.220806
20348.1006.220908
20348.1129.221007
20348.1131.221014
20348.1249.221105
20348.1366.221207
20348.1487.230106
20348.1547.230207
20348.1607.230310
20348.1668.230404
20348.1726.230505
20348.1787.230607
20348.1787.230621
20348.1850.230707
20348.1906.230803
20348.1970.230905
published latest version: 20348.1970.230905 running version: 'latest'
``````
