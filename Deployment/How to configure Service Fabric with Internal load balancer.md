# How to configure Service Fabric with an Internal load balancer

## Overview

The following summarizes the steps required to configure a Service Fabric cluster to use only Internal load balancers. An internal load balancer is load balancer with the front end configuration configured only with private IP addresses and therefore have no public access from internet. Additional information about this configuration is available in [Internal-only load balancer](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking#internal-only-load-balancer) documentation. 

For Service Fabric Managed clusters, refer to [Bring your own Azure Load Balancer](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking#bring-your-own-azure-load-balancer) documentation for internal load balancer options.

## Steps

### Prerequisites

1. Inbound network connectivity to load balancer front end configuration private IP address for [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) or [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-connect-vm-scale-set) is configured for existing / new private network for management of nodes.
2. Outbound network connectivity from node to Service Fabric Resource Provider (SFRP) over port 443. All nodes need to resolve and connect to regionally configured external SFRP https url.

### Template Options

For all internal load balancer configuration scenarios, an ARM template is required since the options are not configurable in the Azure portal. Use one of the options below to create or modify a template.

### Using New Template

An already configured Azure Samples Service Fabric internal load balancer single nodetype template is available here if creating a new ARM template: [5 Node Secure Internal Windows Service Fabric Cluster](https://github.com/Azure-Samples/service-fabric-cluster-templates/tree/master/5-VM-Windows-1-NodeTypes-Secure-ILB).

For deployments needing multiple nodetypes or additional configuration, a new template can be generated in Azure portal [Service Fabric clusters](https://ms.portal.azure.com/#browse/Microsoft.ServiceFabric%2Fclusters) blade with available options using [Creating Service Fabric Cluster via arm](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-via-arm). **Before final step of 'Create'**, select 'Download a template for automation' link to download template for internal load balancer modification using steps below.

  ![Screenshot of downloading Azure deployment template before Create](../media/how-to-configure-service-fabric-with-internal-load-balancer\DownloadTemplate.png)

### Using Existing Template

#### **Modify Existing Portal ARM template**

Steps for template modification are below. See [Template Diff](#template-diff) for example template changes described in steps or [5 Node Secure Internal Windows Service Fabric Cluster](https://github.com/Azure-Samples/service-fabric-cluster-templates/tree/master/5-VM-Windows-1-NodeTypes-Secure-ILB) for a deployable template.

1. Open ARM template for modification.
1. Remove 'dnsName' parameter from 'parameters' section.
1. Optionally add new parameter 'privateIpAddress' if using private static ip.
1. Remove resource 'Microsoft.Network/publicIPAddresses' from 'resources' section.
1. Remove any 'dependsOn' references to the removed 'Microsoft.Network/publicIPAddresses' resource. 'Microsoft.Network/loadBalancers' resource by default has this dependency.
1. Add 'dependsOn' reference to the virtual network 'Microsoft.Network/virtualNetworks' resource in 'Microsoft.Network/loadBalancers' resource if network is not existing.
1. Modify 'Microsoft.Network/loadBalancers' 'frontendIPConfigurations' section. Replace 'publicIPAddress' with 'privateIpAddress' and 'privateIPAllocationMethod' properties. Add required 'subnet' id reference for private IP address configuration.
1. In resource 'Microsoft.ServiceFabric/clusters' modify 'managementEndpoint' to use the internal load balancer ip address.  
  **Note: For security reasons, all clusters should be configured to use a certificate for cluster access and communication. If for some reason the cluster is not using a certificate, the 'managementEndpoint' 'https://' value should be modified to 'http://'.**  
  Example:  

    ```json
    "managementEndpoint": "[concat('https://',reference(variables('lbID0')).frontEndIPConfigurations[0].properties.privateIPAddress,':',parameters('nt0fabricHttpGatewayPort'))]",
    ```

### Deployment

1. Create resource group using PowerShell or Azure portal if it does not currently exist.

    ```powershell
    New-AzResourceGroup -Name <#resource group name#> -Location <#location#>
    ```

1. Deploy template using Azure portal [Templates](https://ms.portal.azure.com/#browse/Microsoft.Gallery%2Fmyareas%2Fgalleryitems) blade or PowerShell 'New-AzResourceGroupDeployment' command.

    ```powershell
    New-AzResourceGroupDeployment -ResourceGroupName <#resource group name#> -TemplateFile $pwd\template.json
    ```

## Reference

### Template Diff

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
+        "[concat('Microsoft.Network/virtualNetworks/', parameters('virtualNetworkName'))]"
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
