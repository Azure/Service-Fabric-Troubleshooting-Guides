# Upgrade Service Fabric cluster from Basic load balancer to Standard load balancer SKU

## Overview  

This documents the overall process of upgrading a basic load balancer sku to standard load balancer sku for a service fabric cluster. [Upgrade a basic load balancer used with Virtual Machine Scale Sets](https://learn.microsoft.com/azure/load-balancer/upgrade-basic-standard-virtual-machine-scale-sets) documents the commands used and detailed information about upgrading the load balancer sku. Upgrading a scaleset / nodetype for a Service Fabric cluster will take longer to complete than documented in link above due to cluster characteristics and requirements. Anticipate a minimum of one hour of downtime for a silver or greater cluster and 30 minutes for bronze.

> ### :exclamation:NOTE: While the following process executes, connectivity to the cluster will be unavailable. 

## Upgrade Process 

- Updates front end public IP addresses to standard sku and static assignment.
- Upgrades the basic load balancer configuration to a new standard load balancer ensuring configuration and feature parity.
- Adds load balancer outbound rule for virtual machine scale set.
- Upgrades virtual machine scale set backend pool members to use the standard load balancer.
- Creates and associates a new network security group (NSG) for connectivity to virtual machine scale set if one is not configured in the scale set network configuration. Standard load balancers require this due to default deny policy. Name will be 'NSG-\<scale set name\>'

## Before migration

Perform the following before starting migration to standard load balancer.

- Verify current cluster configuration is documented. If deploying / recovering cluster via ARM template verify template is current. If ARM template is not available, a non-deployable template with current configuration can be exported from Azure portal in the clusters resource group view by selecting 'Export template'.

- Verify current cluster application configuration is documented. If deploying cluster applications via ARM template verify template is current. Application port settings are normally configured in the applications' manifest file.

- In Service Fabric Explorer (SFX), verify cluster is in a green state and currently healthy.

- If possible, perform migration process on a non-production cluster to familiarize the process and downtime.

### Upgrade Powershell commands

Below are basic powershell commands assuming Azure 'Az' modules are already installed. See link above for additional configurations are that are available. [Example log output](#example-log).

```powershell
$resourceGroupName = '<resource group name>'
$loadBalancerName = '<load balancer name>'
if(!(Get-AzContext)) { Connect-AzAccount }
if(!(Get-Module -listAvailable -Name AzureBasicLoadBalancerUpgrade)) {
    Install-Module -Name AzureBasicLoadBalancerUpgrade -Repository PSGallery -Force
}
Start-AzBasicLoadBalancerUpgrade -ResourceGroupName $resourceGroupName `
    -BasicLoadBalancerName $loadBalancerName `
    -FollowLog
```

## Updating ARM template with changes

Best practice for Service fabric is to deploy, maintain, and recover clusters using ARM templates. After upgrade completes, update ARM template used for cluster deployment. The following base template was created from the Azure portal using a 'silver' 5 node single nodetype cluster. There are some resources in below diff, for example NSG rules, that may or may not apply or may need the tcp ports modified.

```diff
diff --git a/c:/configs/arm/sf-1nt-5n-1lb.json b/c:/configs/arm/sf-1nt-5n-1slb.json
index 0cd7316..8a54ba2 100644
--- a/c:/configs/arm/sf-1nt-5n-1lb.json
+++ b/c:/configs/arm/sf-1nt-5n-1slb.json
@@ -92,10 +92,17 @@
         },
         "lbIPName": {
             "type": "string",
             "defaultValue": "PublicIP-LB-FE"
         },
+        "networkSecurityGroupName": {
+            "type": "string",
+            "defaultValue": "NSG"
+        },
         "nicName": {
             "type": "string",
             "defaultValue": "NIC"
         },
         "nt0applicationEndPort": {
@@ -261,22 +268,27 @@
         {
             "apiVersion": "[variables('vNetApiVersion')]",
             "type": "Microsoft.Network/virtualNetworks",
             "name": "[parameters('virtualNetworkName')]",
             "location": "[parameters('computeLocation')]",
-            "dependsOn": [],
+            "dependsOn": [
+                "[concat('Microsoft.Network/networkSecurityGroups/',parameters('networkSecurityGroupName'))]"
+            ],
             "properties": {
                 "addressSpace": {
                     "addressPrefixes": [
                         "[parameters('addressPrefix')]"
                     ]
                 },
                 "subnets": [
                     {
                         "name": "[parameters('subnet0Name')]",
                         "properties": {
-                            "addressPrefix": "[parameters('subnet0Prefix')]"
+                            "addressPrefix": "[parameters('subnet0Prefix')]",
+                            "networkSecurityGroup": {
+                                "id": "[resourceId('Microsoft.Network/networkSecurityGroups',parameters('networkSecurityGroupName'))]"
+                            }
                         }
                     }
                 ]
             },
             "tags": {
@@ -287,26 +299,147 @@
         {
             "apiVersion": "[variables('publicIPApiVersion')]",
             "type": "Microsoft.Network/publicIPAddresses",
             "name": "[concat(parameters('lbIPName'),'-','0')]",
             "location": "[parameters('computeLocation')]",
+            "sku": {
+                "name": "Standard"
+            },
             "properties": {
                 "dnsSettings": {
                     "domainNameLabel": "[parameters('dnsName')]"
                 },
-                "publicIPAllocationMethod": "Dynamic"
+                "publicIPAllocationMethod": "Static"
             },
             "tags": {
                 "resourceType": "Service Fabric",
                 "clusterName": "[parameters('clusterName')]"
             }
         },
+        {
+            "name": "[parameters('networkSecurityGroupName')]",
+            "type": "Microsoft.Network/networkSecurityGroups",
+            "apiVersion": "2019-02-01",
+            "location": "[parameters('computelocation')]",
+            "properties": {
+                "securityRules": [
+                    {
+                        "name": "SF_AllowServiceFabricGatewayToSFRP",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "This is required rule to allow SFRP to connect to the cluster. This rule cannot be overridden.",
+                            "protocol": "TCP",
+                            "sourcePortRange": "*",
+                            "sourceAddressPrefix": "ServiceFabric",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 500,
+                            "direction": "Inbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [
+                                "19000",
+                                "19080"
+                            ],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    },
+                    {
+                        "name": "SF_AllowServiceFabricGatewayToLB",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "This is required rule to allow SFRP to connect to the cluster. This rule cannot be overridden.",
+                            "protocol": "*",
+                            "sourcePortRange": "*",
+                            "destinationPortRange": "*",
+                            "sourceAddressPrefix": "AzureLoadBalancer",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 501,
+                            "direction": "Inbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    },
+                    {
+                        "name": "SF_AllowServiceFabricGatewayPorts",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "Optional rule to open SF cluster gateway ports.",
+                            "protocol": "tcp",
+                            "sourcePortRange": "*",
+                            "sourceAddressPrefix": "*",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 3001,
+                            "direction": "Inbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [
+                                "19000",
+                                "19080"
+                            ],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    },
// For RDP connectivity if enabled START
+                    {
+                        "name": "SF_AllowRdpPort",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "Optional rule to open RDP ports.",
+                            "protocol": "tcp",
+                            "sourcePortRange": "*",
+                            "destinationPortRange": "3389",
+                            "sourceAddressPrefix": "*",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 3002,
+                            "direction": "Inbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    },
// For RDP connectivity if enabled END
// For Reverse Proxy connectivity if enabled START
+                    {
+                        "name": "SF_AllowReverseProxyPort",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "Optional rule to open SF Reverse Proxy ports.",
+                            "protocol": "tcp",
+                            "sourcePortRange": "*",
+                            "destinationPortRange": "19081",
+                            "sourceAddressPrefix": "*",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 503,
+                            "direction": "Inbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    },
// For Reverse Proxy connectivity if enabled END
+                    {
+                        "name": "SF_AllowSFExtensionToDLC",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "This is required rule to allow SF Extension to connect to download center to download the cab. This rule cannot be overridden.",
+                            "protocol": "*",
+                            "sourcePortRange": "*",
+                            "destinationPortRange": "*",
+                            "sourceAddressPrefix": "*",
+                            "destinationAddressPrefix": "AzureFrontDoor.FirstParty",
+                            "access": "Allow",
+                            "priority": 502,
+                            "direction": "Outbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    }
+                ]
+            }
+        },
         {
             "apiVersion": "[variables('lbApiVersion')]",
             "type": "Microsoft.Network/loadBalancers",
             "name": "[concat('LB','-', parameters('clusterName'),'-',parameters('vmNodeType0Name'))]",
             "location": "[parameters('computeLocation')]",
+            "sku": {
+                "name": "Standard"
+            },
             "dependsOn": [
                 "[concat('Microsoft.Network/publicIPAddresses/',concat(parameters('lbIPName'),'-','0'))]"
             ],
             "properties": {
                 "frontendIPConfigurations": [
@@ -327,10 +460,11 @@
                 ],
                 "loadBalancingRules": [
                     {
                         "name": "LBRule",
                         "properties": {
+                            "disableOutboundSnat": true,
                             "backendAddressPool": {
                                 "id": "[variables('lbPoolID0')]"
                             },
                             "backendPort": "[parameters('nt0fabricTcpGatewayPort')]",
                             "enableFloatingIP": "false",
@@ -346,10 +480,11 @@
                         }
                     },
                     {
                         "name": "LBHttpRule",
                         "properties": {
+                            "disableOutboundSnat": true,
                             "backendAddressPool": {
                                 "id": "[variables('lbPoolID0')]"
                             },
                             "backendPort": "[parameters('nt0fabricHttpGatewayPort')]",
                             "enableFloatingIP": "false",
@@ -383,10 +518,29 @@
                             "port": "[parameters('nt0fabricHttpGatewayPort')]",
                             "protocol": "tcp"
                         }
                     }
                 ],
+                "outboundRules": [
+                    {
+                        "name": "DefaultIPv4",
+                        "properties": {
+                            "allocatedOutboundPorts": 0,
+                            "protocol": "All",
+                            "enableTcpReset": true,
+                            "idleTimeoutInMinutes": 4,
+                            "backendAddressPool": {
+                                "id": "[variables('lbPoolID0')]"
+                            },
+                            "frontendIPConfigurations": [
+                                {
+                                    "id": "[variables('lbIPConfig0')]"
+                                }
+                            ]
+                        }
+                    }
+                ],
                 "inboundNatPools": [
                     {
                         "name": "LoadBalancerBEAddressNatPool",
                         "properties": {
                             "backendPort": "3389",
```

## Verification

After migration to standard load balancer is complete, verify functionality and connectivity.

### Check connectivity

For public load balancers, from an external device / admin machine, open powershell and run the following commands to Service Fabric port connectivity. If there are connectivity issues, verify the NSG security rules. Depending on configuration, there may be multiple NSG's configured for cluster if migration script does not detect an existing NSG.

> ### :exclamation:NOTE: The newly created NSG will not have rules for RDP port access. For RDP access after migration to standard load balancer, add a new rule for RDP in new NSG. 

```powershell
$managementEndpoint = 'sfcluster.eastus.cloudapp.azure.com'
$networkPorts = @(
  19000, # default gateway address
  19080, # default https address
  19081, # default reverse proxy address if enabled
  3389   # default RDP port for node 0 if enabled
) 
foreach($port in $networkPorts) {
  test-netConnection -ComputerName $managementEndpoint -Port $port
}
```

### Check functionality

Check all application / service type ports configured for cluster.

```powershell
$managementEndpoint = 'sfcluster.eastus.cloudapp.azure.com'
$networkPorts = @(443,20000) # add application ports that are publicly accessible
foreach($port in $networkPorts) {
  test-netConnection -ComputerName $managementEndpoint -Port $port
}
```

### Check cluster

Open Service Fabric Explorer (SFX) and verify cluster is 'green' with no warnings or errors. 

Example: https://sfcluster.eastus.cloudapp.azure.com:19080/Explorer

![sfx-green](../media/upgrade-service-fabric-cluster-basic-load-balancer/sfx-green.png)

## Troubleshooting

- Use -Verbose and -Debug arguments for additional logging

    ```powershell
    $resourceGroupName = '<resource group name>'
    $loadBalancerName = '<load balancer name>'
    Start-AzBasicLoadBalancerUpgrade -ResourceGroupName $resourceGroupName `
        -BasicLoadBalancerName $loadBalancerName `
        -FollowLog `
        -Verbose `
        -Debug

    DEBUG: AzureQoSEvent:  Module: Az.Network:5.3.0; CommandName: Get-AzLoadBalancer; PSVersion: 7.3.1; IsSuccess: True; Duration: 00:00:02.4149601  
    DEBUG: 1:16:48 PM - [ConfigManager] Got [True] from [EnableDataCollection], Module = [], Cmdlet = [].  
    DEBUG: 1:16:48 PM - GetAzureRmLoadBalancer end processing.  
    WARNING: [Warning]:[PublicIPToStatic] 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') was using Dynamic IP, changing to Static IP allocation method.  
    WARNING: [Warning]:[PublicFEMigration] 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') is using Basic SKU, changing Standard SKU.  
    WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.0' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!  
    WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.1' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!  
    WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.2' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!  
    WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.3' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!  
    WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.4' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!  
    ```

- Use the latest version of 'AzureBasicLoadBalancerUpgrade'.

    ```powershell
    # clean and install latest AzureBasicLoadBalancerUpgrade module
    Remove-Module AzureBasicLoadBalancerUpgrade
    while(Get-Module AzureBasicLoadBalancerUpgrade -listAvailable) {
        Uninstall-Module AzureBasicLoadBalancerUpgrade -force
    }

    Install-Module -Name AzureBasicLoadBalancerUpgrade -Repository PSGallery -Force
    ```

- Use the latest version of Azure 'Az' modules.

    ```powershell
    # clean and install latest Az module
    Remove-Module Az
    Uninstall-Module Az -Force
    while(Get-Module Az.* -listAvailable) {
        Get-Module Az.* -listAvailable | Uninstall-Module -force
    }

    Install-Module Az -force
    ```

- Check source for new releases or issues [https://github.com/Azure/AzLoadBalancerMigration](https://github.com/Azure/AzLoadBalancerMigration)

- Check SFX Events for any warnings or errors.

  Example: https://sfcluster.eastus.cloudapp.azure.com:19080/Explorer/index.html#/events

  ![](../media/upgrade-service-fabric-cluster-basic-load-balancer/sfx-cluster-events.png)

### Example log

```log
2023-02-06T11:02:39-05 [Information] - ############################## Initializing Start-AzBasicLoadBalancerUpgrade ##############################
2023-02-06T11:02:39-05 [Information] - [Start-AzBasicLoadBalancerUpgrade] Checking that user is signed in to Azure PowerShell
2023-02-06T11:02:39-05 [Information] - [Start-AzBasicLoadBalancerUpgrade] Loading Azure Resources
2023-02-06T11:02:39-05 [Information] - [Start-AzBasicLoadBalancerUpgrade] Basic Load Balancer LB-sfcluster-nt0 loaded
2023-02-06T11:02:39-05 [Information] - [Test-SupportedMigrationScenario] Verifying if Load Balancer LB-sfcluster-nt0 is valid for migration
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Verifying source load balancer SKU
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Source load balancer SKU is type Basic
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Checking if there are any backend pool members which are not virtualMachineScaleSets and that all backend pools are not empty
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] All backend pools members virtualMachineScaleSets!
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Checking if there are more than one VMSS in the backend pool
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Basic Load Balancer has only one VMSS in the backend pool
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Checking that source load balancer is configured
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Load balancer has at least 1 frontend IP configuration
2023-02-06T11:02:40-05 [Information] - [Test-SupportedMigrationScenario] Checking that standard load balancer name 'LB-sfcluster-nt0'
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Load balancer resource 'LB-sfcluster-nt0' already exists. Checking if it is a Basic SKU for migration
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Load balancer resource 'LB-sfcluster-nt0' is a Basic Load Balancer. The same name will be re-used.
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Checking if backend pools contain members which are members of another load balancer's backend pools...
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Checking for instances in backend pool member VMSS 'nt0' with Instance Protection configured
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] No VMSS instances with Instance Protection found
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Checking for VMSS with publicIPConfigurations
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Determining if LB is internal or external based on FrontEndIPConfiguration[0]'s IP configuration
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] FrontEndIPConfiguiration[0] is assigned a public IP address '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Network/publicIPAddresses/PublicIP-LB-FE-0', so this LB is External
2023-02-06T11:02:41-05 [Information] - [Test-SupportedMigrationScenario] Determining if there is a frontend IPV6 configuration
2023-02-06T11:02:42-05 [Information] - [Test-SupportedMigrationScenario] Load Balancer LB-sfcluster-nt0 is valid for migration
2023-02-06T11:02:42-05 [Information] - [PublicLBMigration] Public Load Balancer Detected. Initiating Public Load Balancer Migration
2023-02-06T11:02:42-05 [Information] - [GetVmssFromBasicLoadBalancer] Initiating GetVmssFromBasicLoadBalancer
2023-02-06T11:02:42-05 [Information] - [GetVmssFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0' from Azure
2023-02-06T11:02:43-05 [Information] - [GetVmssFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
2023-02-06T11:02:43-05 [Information] - [BackupBasicLoadBalancer] Initiating Backup of Basic Load Balancer Configurations to path 'C:\temp'
2023-02-06T11:02:43-05 [Information] - [BackupBasicLoadBalancer] JSON backup Basic Load Balancer to file C:\temp\State_LB-sfcluster-nt0_sfcluster_20230206T1102433143.json Completed
2023-02-06T11:02:43-05 [Information] - [BackupBasicLoadBalancer] Exporting Basic Load Balancer ARM template to path 'C:\temp'...
2023-02-06T11:02:48-05 [Information] - [BackupBasicLoadBalancer] Completed export Basic Load Balancer ARM template to path 'C:\temp\ARMTemplate_LB-sfcluster-nt0_sfcluster_20230206T1102433143.json'...
2023-02-06T11:02:48-05 [Information] - [BackupBasicLoadBalancer] Attempting to create a file-based backup VMSS with id '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0'
2023-02-06T11:02:49-05 [Information] - [RemoveVMSSPublicIPConfig] Removing Public IP Address configuration from VMSS 
2023-02-06T11:02:49-05 [Information] - [GetVmssFromBasicLoadBalancer] Initiating GetVmssFromBasicLoadBalancer
2023-02-06T11:02:49-05 [Information] - [GetVmssFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0' from Azure
2023-02-06T11:02:50-05 [Information] - [GetVmssFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
2023-02-06T11:02:50-05 [Information] - [RemoveVMSSPublicIPConfig] Completed removing Public IP Address configuration from VMSS nt0. PIPs removed: 'False'
2023-02-06T11:02:50-05 [Information] - [PublicIPToStatic] Changing public IP addresses to static (if necessary)
2023-02-06T11:02:50-05 [Warning] - [PublicIPToStatic] 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') was using Dynamic IP, changing to Static IP allocation method.
2023-02-06T11:02:53-05 [Information] - [PublicIPToStatic] Completed the migration of 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') from Basic SKU and/or dynamic to static
2023-02-06T11:02:53-05 [Information] - [PublicIPToStatic] Public Frontend Migration Completed
2023-02-06T11:02:53-05 [Information] - [RemoveLoadBalancerFromVmss] Initiating removal of LB LB-sfcluster-nt0 from VMSS 
2023-02-06T11:02:53-05 [Information] - [RemoveLoadBalancerFromVmss] Looping all VMSS from Basic Load Balancer LB-sfcluster-nt0
2023-02-06T11:02:53-05 [Information] - [RemoveLoadBalancerFromVmss] Building VMSS object from Basic Load Balancer LB-sfcluster-nt0
2023-02-06T11:02:53-05 [Information] - [GetVmssFromBasicLoadBalancer] Initiating GetVmssFromBasicLoadBalancer
2023-02-06T11:02:53-05 [Information] - [GetVmssFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0' from Azure
2023-02-06T11:02:54-05 [Information] - [GetVmssFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
2023-02-06T11:02:54-05 [Information] - [RemoveLoadBalancerFromVmss] Cleaning healthProbe from NetworkProfile of VMSS nt0
2023-02-06T11:02:54-05 [Information] - [RemoveLoadBalancerFromVmss] Checking Upgrade Policy Mode of VMSS nt0
2023-02-06T11:02:54-05 [Information] - [RemoveLoadBalancerFromVmss] Cleaning LoadBalancerBackendAddressPools from Basic Load Balancer LB-sfcluster-nt0
2023-02-06T11:02:54-05 [Information] - [RemoveLoadBalancerFromVmss] Updating VMSS nt0
2023-02-06T11:02:54-05 [Information] - [WaitJob] Checking Job Id: 13
2023-02-06T11:18:28-05 [Information] - [WaitJob] Receiving Job: Microsoft.Azure.Commands.Compute.Automation.Models.PSVirtualMachineScaleSet
2023-02-06T11:18:28-05 [Information] - [WaitJob] Job Not Running: Microsoft.Azure.Commands.Common.AzureLongRunningJob`1[Microsoft.WindowsAzure.Commands.Utilities.Common.AzurePSCmdlet]
2023-02-06T11:18:28-05 [Information] - [RemoveJob] Removing Job Id: 13
2023-02-06T11:18:28-05 [Information] - [RemoveJob] Job Removed: 13
2023-02-06T11:18:28-05 [Information] - [WaitJob] Minutes Executing:15 State:Completed
2023-02-06T11:18:28-05 [Information] - [RemoveJob] Removing Job Id: 14
2023-02-06T11:18:28-05 [Information] - [RemoveJob] Job Removed: 14
2023-02-06T11:18:28-05 [Information] - [UpdateVmssInstances] Initiating Update Vmss Instances
2023-02-06T11:18:28-05 [Information] - [UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
2023-02-06T11:18:28-05 [Information] - [UpdateVmssInstances] Update Vmss Instances Completed
2023-02-06T11:18:28-05 [Information] - [RemoveLoadBalancerFromVmss] Removing Basic Loadbalancer LB-sfcluster-nt0 from Resource Group sfcluster
2023-02-06T11:18:38-05 [Information] - [RemoveLoadBalancerFromVmss] Removal of Basic Loadbalancer LB-sfcluster-nt0 Completed
2023-02-06T11:18:38-05 [Information] - [AddVMSSPublicIPConfig] Adding Public IP Address configuration back to VMSS  IP Configs
2023-02-06T11:18:38-05 [Information] - [GetVmssFromBasicLoadBalancer] Initiating GetVmssFromBasicLoadBalancer
2023-02-06T11:18:38-05 [Information] - [GetVmssFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0' from Azure
2023-02-06T11:18:40-05 [Information] - [GetVmssFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
2023-02-06T11:18:40-05 [Information] - [_CreateStandardLoadBalancer] Initiating Standard Load Balancer Creation
2023-02-06T11:18:41-05 [Information] - [_CreateStandardLoadBalancer] Standard Load Balancer LB-sfcluster-nt0 created successfully
2023-02-06T11:18:41-05 [Information] - [PublicFEMigration] Initiating Public Frontend Migration
2023-02-06T11:18:41-05 [Warning] - [PublicFEMigration] 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') is using Basic SKU, changing Standard SKU.
2023-02-06T11:18:43-05 [Information] - [PublicFEMigration] Completed the migration of 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') from Basic SKU and/or dynamic to static
2023-02-06T11:18:43-05 [Information] - [PublicFEMigration] Saving Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:18:46-05 [Information] - [PublicFEMigration] Public Frontend Migration Completed
2023-02-06T11:18:46-05 [Information] - [AddLoadBalancerBackendAddressPool] Adding BackendAddressPool LoadBalancerBEAddressPool
2023-02-06T11:18:46-05 [Information] - [AddLoadBalancerBackendAddressPool] Saving added BackendAddressPool to Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:18:48-05 [Information] - [ProbesMigration] Initiating Probes Migration
2023-02-06T11:18:48-05 [Information] - [ProbesMigration] Adding Probe FabricGatewayProbe to Standard Load Balancer
2023-02-06T11:18:48-05 [Information] - [ProbesMigration] Adding Probe FabricHttpGatewayProbe to Standard Load Balancer
2023-02-06T11:18:48-05 [Information] - [ProbesMigration] Saving Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:18:51-05 [Information] - [ProbesMigration] Probes Migration Completed
2023-02-06T11:18:51-05 [Information] - [LoadBalacingRulesMigration] Initiating LoadBalacing Rules Migration
2023-02-06T11:18:51-05 [Information] - [LoadBalacingRulesMigration] Adding LoadBalacing Rule LBRule to Standard Load Balancer
2023-02-06T11:18:51-05 [Information] - [LoadBalacingRulesMigration] Adding LoadBalacing Rule LBHttpRule to Standard Load Balancer
2023-02-06T11:18:51-05 [Information] - [LoadBalacingRulesMigration] Saving Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:18:53-05 [Information] - [LoadBalacingRulesMigration] LoadBalacing Rules Migration Completed
2023-02-06T11:18:53-05 [Information] - [OutboundRulesCreation] Initiating Outbound Rules Creation
2023-02-06T11:18:53-05 [Information] - [OutboundRulesCreation] Adding Outbound Rule LoadBalancerBEAddressPool to Standard Load Balancer
2023-02-06T11:18:53-05 [Information] - [OutboundRulesCreation] Saving Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:18:56-05 [Information] - [OutboundRulesCreation] Outbound Rules Creation Completed
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Initiating Nat Rules Migration
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.0 to Standard Load Balancer
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.0' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
2023-02-06T11:18:56-05 [Warning] - [NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.0' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.1 to Standard Load Balancer
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.1' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
2023-02-06T11:18:56-05 [Warning] - [NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.1' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.2 to Standard Load Balancer
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.2' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
2023-02-06T11:18:56-05 [Warning] - [NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.2' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.3 to Standard Load Balancer
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.3' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
2023-02-06T11:18:56-05 [Warning] - [NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.3' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.4 to Standard Load Balancer
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.4' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
2023-02-06T11:18:56-05 [Warning] - [NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.4' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
2023-02-06T11:18:56-05 [Information] - [NatRulesMigration] Saving Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:18:58-05 [Information] - [NatRulesMigration] Nat Rules Migration Completed
2023-02-06T11:18:58-05 [Information] - [InboundNatPoolsMigration] Initiating Inbound NAT Pools Migration
2023-02-06T11:18:58-05 [Information] - [InboundNatPoolsMigration] Adding Inbound NAT Pool LoadBalancerBEAddressNatPool to Standard Load Balancer
2023-02-06T11:18:58-05 [Information] - [InboundNatPoolsMigration] Saving Standard Load Balancer LB-sfcluster-nt0
2023-02-06T11:19:01-05 [Information] - [GetVmssFromBasicLoadBalancer] Initiating GetVmssFromBasicLoadBalancer
2023-02-06T11:19:01-05 [Information] - [GetVmssFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0' from Azure
2023-02-06T11:19:01-05 [Information] - [GetVmssFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
2023-02-06T11:19:01-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding InboundNATPool to VMSS nt0
2023-02-06T11:19:01-05 [Debug] - Getting NAT Pool name from ID: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Network/loadBalancers/LB-sfcluster-nt0/inboundNatPools/LoadBalancerBEAddressNatPool'
2023-02-06T11:19:01-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Checking if VMSS 'nt0' NIC 'NIC-0' IPConfig 'NIC-0' should be associated with NAT Pool 'LoadBalancerBEAddressNatPool'
2023-02-06T11:19:01-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding NAT Pool 'LoadBalancerBEAddressNatPool' to IPConfig 'NIC-0'
2023-02-06T11:19:01-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Migrate NetworkInterface Configurations completed
2023-02-06T11:19:01-05 [Information] - [_UpdateAzVmss] Saving VMSS nt0
2023-02-06T11:19:01-05 [Information] - [WaitJob] Checking Job Id: 16
2023-02-06T11:35:26-05 [Information] - [WaitJob] Receiving Job: Microsoft.Azure.Commands.Compute.Automation.Models.PSVirtualMachineScaleSet
2023-02-06T11:35:26-05 [Information] - [WaitJob] Job Not Running: Microsoft.Azure.Commands.Common.AzureLongRunningJob`1[Microsoft.WindowsAzure.Commands.Utilities.Common.AzurePSCmdlet]
2023-02-06T11:35:26-05 [Information] - [RemoveJob] Removing Job Id: 16
2023-02-06T11:35:26-05 [Information] - [RemoveJob] Job Removed: 16
2023-02-06T11:35:26-05 [Information] - [WaitJob] Minutes Executing:16 State:Completed
2023-02-06T11:35:26-05 [Information] - [RemoveJob] Removing Job Id: 17
2023-02-06T11:35:26-05 [Information] - [RemoveJob] Job Removed: 17
2023-02-06T11:35:26-05 [Information] - [UpdateVmssInstances] Initiating Update Vmss Instances
2023-02-06T11:35:26-05 [Information] - [UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
2023-02-06T11:35:26-05 [Information] - [UpdateVmssInstances] Update Vmss Instances Completed
2023-02-06T11:35:26-05 [Information] - [InboundNatPoolsMigration] Inbound NAT Pools Migration Completed
2023-02-06T11:35:26-05 [Information] - [NsgCreation] Initiating NSG Creation
2023-02-06T11:35:26-05 [Information] - [NsgCreation] Looping all VMSS in the backend pool of the Load Balancer
2023-02-06T11:35:27-05 [Information] - [NsgCreation] Checking if VMSS Named: nt0 has a NSG
2023-02-06T11:35:30-05 [Information] - [NsgCreation] NSG detected in Subnet for VMSS Named: nt0 Subnet.NetworkSecurityGroup Id: /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Network/networkSecurityGroups/VNet-Subnet-0-nsg-eastus
2023-02-06T11:35:30-05 [Information] - [NsgCreation] NSG will not be created for VMSS Named: nt0
2023-02-06T11:35:30-05 [Information] - [NsgCreation] NSG Creation Completed
2023-02-06T11:35:30-05 [Information] - [BackendPoolMigration] Initiating Backend Pool Migration
2023-02-06T11:35:30-05 [Information] - [BackendPoolMigration] Adding Standard Load Balancer back to the VMSS
2023-02-06T11:35:30-05 [Information] - [BackendPoolMigration] Building VMSS object from Basic Load Balancer LB-sfcluster-nt0
2023-02-06T11:35:30-05 [Information] - [GetVmssFromBasicLoadBalancer] Initiating GetVmssFromBasicLoadBalancer
2023-02-06T11:35:30-05 [Information] - [GetVmssFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/sfcluster/providers/microsoft.compute/virtualmachinescalesets/nt0' from Azure
2023-02-06T11:35:31-05 [Information] - [GetVmssFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
2023-02-06T11:35:31-05 [Information] - [_MigrateHealthProbe] Migrating Health Probes
2023-02-06T11:35:31-05 [Information] - [_MigrateHealthProbe] Health Probes not found in reference VMSS nt0
2023-02-06T11:35:31-05 [Information] - [_MigrateHealthProbe] Migrating Health Probes completed
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool to VMSS nt0
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
2023-02-06T11:35:31-05 [Information] - [_MigrateNetworkInterfaceConfigurations] Migrate NetworkInterface Configurations completed
2023-02-06T11:35:31-05 [Information] - [UpdateVmss] Updating configuration of VMSS 'nt0'
2023-02-06T11:35:31-05 [Information] - [WaitJob] Checking Job Id: 19
2023-02-06T11:51:05-05 [Information] - [WaitJob] Receiving Job: Microsoft.Azure.Commands.Compute.Automation.Models.PSVirtualMachineScaleSet
2023-02-06T11:51:05-05 [Information] - [WaitJob] Job Not Running: Microsoft.Azure.Commands.Common.AzureLongRunningJob`1[Microsoft.WindowsAzure.Commands.Utilities.Common.AzurePSCmdlet]
2023-02-06T11:51:05-05 [Information] - [RemoveJob] Removing Job Id: 19
2023-02-06T11:51:05-05 [Information] - [RemoveJob] Job Removed: 19
2023-02-06T11:51:05-05 [Information] - [WaitJob] Job Complete: Minutes Executing:15 State:Completed
2023-02-06T11:51:05-05 [Information] - [RemoveJob] Removing Job Id: 20
2023-02-06T11:51:05-05 [Information] - [RemoveJob] Job Removed: 20
2023-02-06T11:51:05-05 [Information] - [UpdateVmss] Completed update configuration of VMSS 'nt0'
2023-02-06T11:51:05-05 [Information] - [UpdateVmssInstances] Initiating Update Vmss Instances
2023-02-06T11:51:05-05 [Information] - [UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
2023-02-06T11:51:05-05 [Information] - [UpdateVmssInstances] Update Vmss Instances Completed
2023-02-06T11:51:05-05 [Information] - [_RestoreUpgradePolicyMode] Restoring VMSS Upgrade Policy Mode
2023-02-06T11:51:05-05 [Information] - [_RestoreUpgradePolicyMode] VMSS Upgrade Policy Mode not changed
2023-02-06T11:51:05-05 [Information] - [_RestoreUpgradePolicyMode] Restoring VMSS Upgrade Policy Mode completed
2023-02-06T11:51:05-05 [Information] - [UpdateVmss] Updating configuration of VMSS 'nt0'
2023-02-06T11:51:05-05 [Information] - [WaitJob] Checking Job Id: 22
2023-02-06T11:51:22-05 [Information] - [WaitJob] Receiving Job: Microsoft.Azure.Commands.Compute.Automation.Models.PSVirtualMachineScaleSet
2023-02-06T11:51:22-05 [Information] - [WaitJob] Job Not Running: Microsoft.Azure.Commands.Common.AzureLongRunningJob`1[Microsoft.WindowsAzure.Commands.Utilities.Common.AzurePSCmdlet]
2023-02-06T11:51:22-05 [Information] - [RemoveJob] Removing Job Id: 22
2023-02-06T11:51:22-05 [Information] - [RemoveJob] Job Removed: 22
2023-02-06T11:51:22-05 [Information] - [WaitJob] Job Complete: Minutes Executing:0 State:Completed
2023-02-06T11:51:22-05 [Information] - [RemoveJob] Removing Job Id: 23
2023-02-06T11:51:22-05 [Information] - [RemoveJob] Job Removed: 23
2023-02-06T11:51:22-05 [Information] - [UpdateVmss] Completed update configuration of VMSS 'nt0'
2023-02-06T11:51:22-05 [Information] - [BackendPoolMigration] Backend Pool Migration Completed
2023-02-06T11:51:22-05 [Information] - ############################## Migration Completed ##############################
```