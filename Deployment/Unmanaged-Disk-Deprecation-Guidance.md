# Deprecation of Azure unmanaged disks guidance for Service Fabric clusters

## Abstract

Azure unmanaged disks deprecation announced September 2022, will be full retired September 2025. All Service Fabric clusters using node types / virtual machine scale sets (VMSS) will need to have new node types with managed disk configuration added to the cluster before this date. See [Migrate your Azure unmanaged disks by September 30, 2025](https://learn.microsoft.com/azure/virtual-machines/unmanaged-disks-deprecation) for detailed information about unmanaged disk deprecation.

## Determining Impact

This deprecation does not affect [Service Fabric Managed clusters](https://learn.microsoft.com/azure/service-fabric/overview-managed-cluster) as all managed clusters are built with managed disk configuration for provisioned node types. This should also not impact any recently built Service Fabric clusters built from Azure Portal since unmanaged disks have not been used for many years in the Service Fabric portal templates.

To conclusively verify whether there are any scale sets using unmanaged disks, each scale set can be viewed in Azure portal, in ARM template, or using powershell commands as shown in example below:

### ARM Template

#### **Example ARM Template VMSS resource using managed disks:**

```json
"storageProfile": {
  "imageReference": {
    "publisher": "[parameters('vmImagePublisher')]",
    "offer": "[parameters('vmImageOffer')]",
    "sku": "[parameters('vmImageSku')]",
    "version": "[parameters('vmImageVersion')]"
  },
  "osDisk": {
    "caching": "ReadOnly",
    "createOption": "FromImage",
    "diskSizeGb": 128,
    "managedDisk": {
      "storageAccountType": "[parameters('storageAccountType')]"
    }
  }
}
```

#### **Example ARM Template VMSS resource using unmanaged disks:**

```json
"storageProfile": {
  "imageReference": {
    "publisher": "[parameters('vmImagePublisher')]",
    "offer": "[parameters('vmImageOffer')]",
    "sku": "[parameters('vmImageSku')]",
    "version": "[parameters('vmImageVersion')]"
  },
  "osDisk": {
    "vhdContainers": [
      "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[0]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
      "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[1]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
      "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[2]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
      "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[3]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
      "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[4]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]"
    ],
    "name": "vmssosdisk",
    "caching": "ReadOnly",
    "createOption": "FromImage"
  }
}
```

### Azure Portal

In [Azure portal](https://ms.portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.Compute%2FvirtualMachineScaleSets), navigate to each scale sets 'Overview' page. In right pane under 'Disk' section, 'Managed disks' will be set to either 'Enabled' or 'Disabled'.

![Screenshot of Scale Set Overview.](../media/unmanaged-disk-deprecation-guidance/azure-portal-managed-disk-disabled.png)

### PowerShell

```powershell
import-module az.resources
import-module az.compute

if (!(get-azResourceGroup)) { connect-azAccount }

$scalesets = get-azResource -ResourceType 'Microsoft.Compute/virtualMachineScaleSets'
if (!$scalesets) {
    write-error "no scale sets enumerated. if this is in error, try from https://shell.azure.com"
}

foreach ($scaleset in $scalesets) {
    $vmss = get-azVmss -ResourceGroupName $scaleset.ResourceGroupName -VMScaleSetName $scaleset.Name
    $extensionTypes = $vmss.VirtualMachineProfile.ExtensionProfile.Extensions.type
    $storageProfile = $vmss.VirtualMachineProfile.StorageProfile
    $scalesetName = $scaleset.Name

    write-host "checking scale set:$($vmss.Id)" -ForegroundColor Cyan
    write-verbose "checking scale set:$($vmss | convertTo-json -Depth 99)"

    if ($extensionTypes -contains 'ServiceFabricNode' -or $extensionTypes -contains 'ServiceFabricLinuxNode') {
        write-host "`t$scalesetName is part of a service fabric cluster" -ForegroundColor Yellow
    }
    elseif ($extensionTypes -contains 'ServiceFabricMCNode') {
        write-host "`t$scalesetName is part of a service fabric managed cluster"
    }
    else {
        write-host "`t$scalesetName is not part of a service fabric cluster"
    }

    if ($storageProfile.OsDisk -and !$storageProfile.OsDisk.ManagedDisk) {
        write-host "`tUNMANAGED DISK: $scalesetName is not using managed disk for os disk" -ForegroundColor Red
    }
    elseif ($storageProfile.OsDisk -and $storageProfile.OsDisk.ManagedDisk) {
        write-host "`t$scalesetName is using managed disk for os disk" -ForegroundColor Green
    }
    else {
        write-error "$scalesetName unable to enumerate os disk:$($vmss | convertTo-json -Depth 99)"
    }

    if ($storageProfile.DataDisks -and !$storageProfile.DataDisks.ManagedDisk) {
        write-host "`tUNMANAGED DISK: $scalesetName is not using managed disks for data disks" -ForegroundColor Red
    }
    elseif ($storageProfile.DataDisks -and $storageProfile.DataDisks.ManagedDisk) {
        write-host "`t$scalesetName is using managed disks for data disks" -ForegroundColor Green
    }
    else {
        write-host "`t$scalesetName unable to enumerate / no data disk"
    }
}
```

#### **Example output:**

```text
checking scale set:/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/unmanagedCluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt1vm
        nt1vm is part of a service fabric cluster
        UNMANAGED DISK: nt1vm is not using managed disk for os disk
        nt1vm unable to enumerate / no data disk
checking scale set:/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/managedCluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt1vm
        nt1vm is part of a service fabric cluster
        nt1vm is using managed disk for os disk
        nt1vm unable to enumerate / no data disk
```

## **Mitigation Options**

Choose one of the options below based on whether cluster requires continuous availability or not.

## Option 1: Full rebuild of cluster

This scenario fits where availability loss is acceptable, and effort is less through automation.

Steps

1. Full rebuild of Service Fabric cluster using Azure managed disks.
2. Re-deploy applications

> :exclamation:
> Please consider the option to recreate the cluster by only removing the Azure Virtual Machine Scale Sets (VMSS) and the Azure Service Fabric cluster resource. Creating just these two instances works well when you don't automate the whole deployment.

Documentation:

- [Quickstart: Create a Service Fabric cluster using ARM template](https://docs.microsoft.com/azure/service-fabric/quickstart-cluster-template)
- [How To: Rebuild Azure Service Fabric cluster (minimal version)](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Deployment/Minimal-Cluster-Rebuild.md)

## Option 2: Add new node type with managed disk and migrate workloads

The mitigation by adding a new Service Fabric node type and migrating the workload has the best cost benefit and the lowest risk in production by providing the highest availability.

### Primary node type using unmanaged disks

Upgrade primary SKU to supported Azure managed disks by following the linked documentation.

Documentation:

- [Scale up a Service Fabric cluster primary node type](https://docs.microsoft.com/azure/service-fabric/service-fabric-scale-up-primary-node-type)

### Secondary node type using unmanaged disks

Add new secondary node types with supported Azure managed disks by following the linked documentation.

Documentation:

- [Scale a Service Fabric cluster out by adding a virtual machine scale set](https://docs.microsoft.com/azure/service-fabric/virtual-machine-scale-set-scale-node-type-scale-out)
- [Scale up a Service Fabric cluster secondary node type](https://learn.microsoft.com/azure/service-fabric/service-fabric-scale-up-non-primary-node-type)

### Migrate workloads

For each option, running workloads need to be moved by changing placement constraints or application upgrades.

Documentation:

- [Configuring placement constraints for Service Fabric services](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-configure-services#placement-constraints)
- [Service Fabric application upgrade](https://docs.microsoft.com/azure/service-fabric/service-fabric-application-upgrade)
- [Stateful service replica set size configuration](https://docs.microsoft.com/azure/service-fabric/service-fabric-best-practices-replica-set-size-configuration)

## ARM Template changes for managed disks

Below is a diff of ARM template changes needed to change provisioning from unmanaged to managed disks for the OS disk for a 5 node cluster.

> ### :exclamation:NOTE: Additional or different changes may be necessary depending on configuration and for additional disk types, for example, 'Data Disks'.

```diff
diff --git a/sf-1nt-5n-1lb-managed-disks.json b/sf-1nt-5n-1lb-managed-disks.json
index 3967309..ffd2d1e 100644
--- a/sf-1nt-5n-1lb-managed-disks.json
+++ b/sf-1nt-5n-1lb-managed-disks.json
@@ -159,7 +159,6 @@
   "variables": {
     "computeLocation": "[parameters('clusterLocation')]",
     "dnsName": "[parameters('clusterName')]",
-    "vmStorageAccountName": "[toLower(concat(uniqueString(resourceGroup().id), '1' ))]",
     "vmName": "vm",
     "publicIPAddressName": "PublicIP-VM",
     "publicIPAddressType": "Dynamic",
@@ -173,7 +172,7 @@
     "maxPercentUpgradeDomainDeltaUnhealthyNodes": "100",
     "vnetID": "[resourceId('Microsoft.Network/virtualNetworks',variables('virtualNetworkName'))]",
     "overProvision": "false",
-    "vmssApiVersion": "2016-03-30",
+    "vmssApiVersion": "2022-11-01",
     "lbApiVersion": "2015-06-15",
     "vNetApiVersion": "2015-06-15",
     "storageApiVersion": "2016-01-01",
@@ -196,15 +195,7 @@
     "lbHttpProbeID0": "[concat(variables('lbID0'),'/probes/FabricHttpGatewayProbe')]",
     "lbNatPoolID0": "[concat(variables('lbID0'),'/inboundNatPools/LoadBalancerBEAddressNatPool')]",
     "vmNodeType0Name": "[toLower(concat('NT1', variables('vmName')))]",
-    "vmNodeType0Size": "Standard_D2",
-    "vmStorageAccountName0": "[toLower(concat(uniqueString(resourceGroup().id), '1', '0' ))]",
-    "uniqueStringArray0": [
-      "[concat(variables('vmStorageAccountName0'), '0')]",
-      "[concat(variables('vmStorageAccountName0'), '1')]",
-      "[concat(variables('vmStorageAccountName0'), '2')]",
-      "[concat(variables('vmStorageAccountName0'), '3')]",
-      "[concat(variables('vmStorageAccountName0'), '4')]"
-    ]
+    "vmNodeType0Size": "Standard_D2"
   },
   "resources": [
     {
@@ -451,30 +442,6 @@
         "clusterName": "[parameters('clusterName')]"
       }
     },
-    {
-      "apiVersion": "[variables('storageApiVersion')]",
-      "type": "Microsoft.Storage/storageAccounts",
-      "name": "[variables('uniqueStringArray0')[copyIndex()]]",
-      "location": "[variables('computeLocation')]",
-      "dependsOn": [
-        
-      ],
-      "properties": {
-        
-      },
-      "copy": {
-        "name": "storageLoop",
-        "count": 5
-      },
-      "kind": "Storage",
-      "sku": {
-        "name": "[parameters('storageAccountType')]"
-      },
-      "tags": {
-        "resourceType": "Service Fabric",
-        "clusterName": "[parameters('clusterName')]"
-      }
-    },
     {
       "apiVersion": "[variables('vmssApiVersion')]",
       "type": "Microsoft.Compute/virtualMachineScaleSets",
@@ -482,11 +473,6 @@
       "location": "[variables('computeLocation')]",
       "dependsOn": [
         "[concat('Microsoft.Network/virtualNetworks/', variables('virtualNetworkName'))]",
-        "[concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[0])]",
-        "[concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[1])]",
-        "[concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[2])]",
-        "[concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[3])]",
-        "[concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[4])]",
         "[concat('Microsoft.Network/loadBalancers/', concat('LB','-', parameters('clusterName'),'-',variables('vmNodeType0Name')))]",
         "[concat('Microsoft.Storage/storageAccounts/', variables('supportLogStorageAccountName'))]",
         "[concat('Microsoft.Storage/storageAccounts/', variables('applicationDiagnosticsStorageAccountName'))]"
@@ -633,16 +619,12 @@
               "version": "[parameters('vmImageVersion')]"
             },
             "osDisk": {
-              "vhdContainers": [
-                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[0]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
-                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[1]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
-                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[2]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
-                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[3]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]",
-                "[concat(reference(concat('Microsoft.Storage/storageAccounts/', variables('uniqueStringArray0')[4]), variables('storageApiVersion')).primaryEndpoints.blob, variables('vmStorageAccountContainerName'))]"
-              ],
-              "name": "vmssosdisk",
               "caching": "ReadOnly",
-              "createOption": "FromImage"
+              "createOption": "FromImage",
+              "diskSizeGb": 128,
+              "managedDisk": {
+                "storageAccountType": "[parameters('storageAccountType')]"
+              }
             }
           }
         }
```

## Frequently Asked Questions


## Reference

[Introduction to Azure managed disks](https://learn.microsoft.com/azure/virtual-machines/managed-disks-overview)
[Azure managed disk types](https://learn.microsoft.com/azure/virtual-machines/disks-types)
[Microsoft.Compute virtualMachineScaleSets](https://learn.microsoft.com/azure/templates/microsoft.compute/virtualmachinescalesets?pivots=deployment-language-arm-template)