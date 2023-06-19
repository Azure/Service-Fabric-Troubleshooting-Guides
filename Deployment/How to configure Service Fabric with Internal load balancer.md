# How to configure Service Fabric with an Internal load balancer

## Overview

The following summarizes the steps required to configure a Service Fabric cluster to use only Internal load balancers. Additional information about this configuration is available in [Internal-only load balancer](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking#internal-only-load-balancer) documentation. An example internal load balancer template is also available here: [5 Node Secure Internal Windows Service Fabric Cluster](https://github.com/Azure-Samples/service-fabric-cluster-templates/tree/master/5-VM-Windows-1-NodeTypes-Secure-ILB).

For Service Fabric Managed clusters, refer to [Bring your own Azure Load Balancer](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking#bring-your-own-azure-load-balancer) documentation for internal load balancer options.

> ### :exclamation:NOTE: Configuring load balancers with only internal ip addresses may prevent management of cluster resources from cluster view in Azure portal if Service Fabric Resource Provider (SFRP) does not have access. Understand these ramifications and access required before implementing. [Allowing the Service Fabric resource provider to query your cluster](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking#allowing-the-service-fabric-resource-provider-to-query-your-cluster) describes the limitation.

## Steps

### Prerequisites

1. Ensure network connectivity exists for [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) or [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-connect-vm-scale-set) is configured for existing / new private network for management of nodes.
1. If existing ARM template is not available, create a new Service Fabric ARM template from Azure portal and download template **before** deployment from Azure portal in [Service Fabric clusters](https://ms.portal.azure.com/#browse/Microsoft.ServiceFabric%2Fclusters) blade.

    ![Screenshot of downloading Azure deployment template before Create](../media/how-to-configure-service-fabric-with-internal-load-balancer\DownloadTemplate.png)

### Modify ARM template

Steps for template modification are below. See [Template Diff](#template-diff) for example template changes described in steps or [5 Node Secure Internal Windows Service Fabric Cluster](https://github.com/Azure-Samples/service-fabric-cluster-templates/tree/master/5-VM-Windows-1-NodeTypes-Secure-ILB) for a deployable template.

1. Open ARM template for modification.
1. Remove 'dnsName' parameter from 'parameters' section.
1. Optionally add new parameter 'privateIpAddress' if using private static ip.
1. Remove resource 'Microsoft.Network/publicIPAddresses' from 'resources' section.
1. Remove any 'dependsOn' references to the removed 'Microsoft.Network/publicIPAddresses' resource in 'Microsoft.Network/loadBalancers' resource.
1. Modify 'Microsoft.Network/loadBalancers' 'frontendIPConfigurations' section. Replace 'publicIPAddress' with 'privateIpAddress' and 'privateIPAllocationMethod' properties. Add required 'subnet' id reference for private IP address configuration.
1. In resource 'Microsoft.ServiceFabric/clusters' modify 'managementEndpoint' to use the internal load balancer ip address.  
  **Note: For security reasons, all clusters should be configured to use a certificate for cluster access and communication. If for some reason the cluster is not using a certificate, the 'managementEndpoint' 'https://' value should be modified to 'http://'.**  
  Example:  

    ```json
    "managementEndpoint": "[concat('https://',reference(variables('lbID0')).frontEndIPConfigurations[0].properties.privateIPAddress,':',parameters('nt0fabricHttpGatewayPort'))]",
    ```

1. Create resource group if not exists and deploy template using Azure portal or PowerShell 'new-azresourceGroupDeployment' command.

    ```powershell
    New-AzResourceGroup -Name <#resource group name#> -Location <#location#>

    New-AzResourceGroupDeployment -ResourceGroupName <#resource group name#> -TemplateFile $pwd\template.json
    ```

## Template Diff

Template diff based on a secure Service Fabric 5 node, 1 nodetype, Silver durability cluster running Windows 2022 Datacenter.

```diff
diff --git a/portal-template-json b/portal-template-json
index fe0bb2e..6fa54e3 100644
--- a/portal-template-json
+++ b/portal-template-json
@@ -51,14 +51,15 @@
     "computeLocation": {
       "type": "string"
     },
-    "publicIPAddressName": {
+    "privateIpAddress": {
       "type": "string",
-      "defaultValue": "PublicIP-VM"
+      "defaultValue": "10.0.0.250"
     },
-    "publicIPAddressType": {
+    "privateIPAddressType": {
       "type": "string",
       "allowedValues": [
-        "Dynamic"
+        "Dynamic",
+        "Static"
       ],
       "defaultValue": "Dynamic"
     },
@@ -87,9 +88,6 @@
       "type": "string",
       "defaultValue": "10.0.0.0/16"
     },
-    "dnsName": {
-      "type": "string"
-    },
     "nicName": {
       "type": "string",
       "defaultValue": "NIC"
@@ -100,7 +98,7 @@
     },
     "lbIPName": {
       "type": "string",
-      "defaultValue": "PublicIP-LB-FE"
+      "defaultValue": "InternalIP-LB-FE"
     },
     "overProvision": {
       "type": "string",
@@ -247,7 +245,6 @@
     "lbApiVersion": "2015-06-15",
     "vNetApiVersion": "2015-06-15",
     "storageApiVersion": "2019-04-01",
-    "publicIPApiVersion": "2015-06-15",
     "vnetID": "[resourceId('Microsoft.Network/virtualNetworks',parameters('virtualNetworkName'))]",
     "subnet0Ref": "[concat(variables('vnetID'),'/subnets/',parameters('subnet0Name'))]",
     "lbID0": "[resourceId('Microsoft.Network/loadBalancers', concat('LB','-', parameters('clusterName'),'-',parameters('vmNodeType0Name')))]",
@@ -321,38 +318,23 @@
         "clusterName": "[parameters('clusterName')]"
       }
     },
-    {
-      "apiVersion": "[variables('publicIPApiVersion')]",
-      "type": "Microsoft.Network/publicIPAddresses",
-      "name": "[concat(parameters('lbIPName'),'-',parameters('vmNodeType0Name'))]",
-      "location": "[parameters('computeLocation')]",
-      "properties": {
-        "dnsSettings": {
-          "domainNameLabel": "[parameters('dnsName')]"
-        },
-        "publicIPAllocationMethod": "Dynamic"
-      },
-      "tags": {
-        "resourceType": "Service Fabric",
-        "clusterName": "[parameters('clusterName')]"
-      }
-    },
     {
       "apiVersion": "[variables('lbApiVersion')]",
       "type": "Microsoft.Network/loadBalancers",
       "name": "[concat('LB','-', parameters('clusterName'),'-',parameters('vmNodeType0Name'))]",
       "location": "[parameters('computeLocation')]",
       "dependsOn": [
-        "[concat('Microsoft.Network/publicIPAddresses/',concat(parameters('lbIPName'),'-',parameters('vmNodeType0Name')))]"
       ],
       "properties": {
         "frontendIPConfigurations": [
           {
             "name": "LoadBalancerIPConfig",
             "properties": {
-              "publicIPAddress": {
-                "id": "[resourceId('Microsoft.Network/publicIPAddresses',concat(parameters('lbIPName'),'-',parameters('vmNodeType0Name')))]"
-              }
+              "subnet": {
+                "id": "[variables('subnet0Ref')]"
+              },
+              "privateIPAddress": "[parameters('privateIpAddress')]",
+              "privateIPAllocationMethod": "[parameters('privateIPAddressType')]"
             }
           }
         ],
@@ -657,7 +639,7 @@
             "name": "Security"
           }
         ],
-        "managementEndpoint": "[concat('https://',reference(concat(parameters('lbIPName'),'-',parameters('vmNodeType0Name'))).dnsSettings.fqdn,':',parameters('nt0fabricHttpGatewayPort'))]",
+        "managementEndpoint": "[concat('https://',reference(variables('lbID0')).frontEndIPConfigurations[0].properties.privateIPAddress,':',parameters('nt0fabricHttpGatewayPort'))]",
         "nodeTypes": [
           {
             "name": "[parameters('vmNodeType0Name')]",
@@ -693,4 +675,4 @@
       "type": "object"
     }
   }
-}
\ No newline at end of file
+}
```
