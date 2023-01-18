# Upgrade Service Fabric cluster from Basic load balancer to Standard load balancer SKU

## Overview  

This documents the overall process of upgrading a basic load balancer sku to standard load balancer sku for a service fabric cluster. [Upgrade a basic load balancer used with Virtual Machine Scale Sets](https://learn.microsoft.com/azure/load-balancer/upgrade-basic-standard-virtual-machine-scale-sets) documents the commands used and detailed information about upgrading the load balancer sku. Upgrading a scaleset / nodetype for a Service Fabric cluster will take longer to complete than documented in link above due to cluster characteristics and requirements. Anticipate a minimum of one hour of downtime.

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

After upgrade completes, update template information used for cluster deployment and recovery.

### Default 5 node silver reliability template diff

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
+                            "description": "Optional rule to open SF cluster gateway ports. To override add a custom NSG rule for gateway ports in priority range 1000-3000.",
+                            "protocol": "tcp",
+                            "sourcePortRange": "*",
+                            "sourceAddressPrefix": "*",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 3002,
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
+                        "name": "SF_AllowRdpPort",
+                        "type": "Microsoft.Network/networkSecurityGroups/securityRules",
+                        "properties": {
+                            "provisioningState": "Succeeded",
+                            "description": "Optional rule to open RDP ports. To override add a custom NSG rule for RDP port in priority range 1000-3000.",
+                            "protocol": "tcp",
+                            "sourcePortRange": "*",
+                            "destinationPortRange": "3389",
+                            "sourceAddressPrefix": "*",
+                            "destinationAddressPrefix": "VirtualNetwork",
+                            "access": "Allow",
+                            "priority": 3003,
+                            "direction": "Inbound",
+                            "sourcePortRanges": [],
+                            "destinationPortRanges": [],
+                            "sourceAddressPrefixes": [],
+                            "destinationAddressPrefixes": []
+                        }
+                    },
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

![](../media/upgrade-service-fabric-cluster-basic-load-balancer/sfx-green.png)

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
PS C:\> start-AzBasicLoadBalancerUpgrade -ResourceGroupName sfcluster -BasicLoadBalancerName LB-sfcluster-nt0 -FollowLog
[Information]:############################## Initializing Start-AzBasicLoadBalancerUpgrade ##############################
[Information]:[Start-AzBasicLoadBalancerUpgrade] Checking that user is signed in to Azure PowerShell
[Information]:[Start-AzBasicLoadBalancerUpgrade] Loading Azure Resources
[Information]:[Start-AzBasicLoadBalancerUpgrade] Basic Load Balancer LB-sfcluster-nt0 loaded
[Information]:[Test-SupportedMigrationScenario] Verifying if Load Balancer LB-sfcluster-nt0 is valid for migration
[Information]:[Test-SupportedMigrationScenario] Verifying source load balancer SKU
[Information]:[Test-SupportedMigrationScenario] Source load balancer SKU is type Basic
[Information]:[Test-SupportedMigrationScenario] Checking if there are any backend pool members which are not virtualMachineScaleSets and that all backend pools are not empty
[Information]:[Test-SupportedMigrationScenario] All backend pools members virtualMachineScaleSets!
[Information]:[Test-SupportedMigrationScenario] Checking if there are more than one VMSS in the backend pool
[Information]:[Test-SupportedMigrationScenario] Basic Load Balancer has only one VMSS in the backend pool
[Information]:[Test-SupportedMigrationScenario] Checking that source load balancer is configured
[Information]:[Test-SupportedMigrationScenario] Load balancer has at least 1 frontend IP configuration
[Information]:[Test-SupportedMigrationScenario] Checking that standard load balancer name 'LB-sfcluster-nt0'
[Information]:[Test-SupportedMigrationScenario] Load balancer resource 'LB-sfcluster-nt0' already exists. Checking if it is a Basic SKU for migration
[Information]:[Test-SupportedMigrationScenario] Load balancer resource 'LB-sfcluster-nt0' is a Basic Load Balancer. The same name will be re-used.
[Information]:[Test-SupportedMigrationScenario] Checking if backend pools contain members which are members of another load balancer's backend pools...
[Information]:[Test-SupportedMigrationScenario] Checking for instances in backend pool member VMSS 'nt0' with Instance Protection configured
[Information]:[Test-SupportedMigrationScenario] No VMSS instances with Instance Protection found
[Information]:[Test-SupportedMigrationScenario] Checking for VMSS with publicIPConfigurations
[Information]:[Test-SupportedMigrationScenario] Determining if LB is internal or external based on FrontEndIPConfiguration[0]'s IP configuration
[Information]:[Test-SupportedMigrationScenario] FrontEndIPConfiguiration[0] is assigned a public IP address '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Network/publicIPAddresses/PublicIP-LB-FE-0', so this LB is External
[Information]:[Test-SupportedMigrationScenario] Determining if there is a frontend IPV6 configuration
[Information]:[Test-SupportedMigrationScenario] Load Balancer LB-sfcluster-nt0 is valid for migration
[Information]:[PublicLBMigration] Public Load Balancer Detected. Initiating Public Load Balancer Migration
[Information]:[GetVMSSFromBasicLoadBalancer] Initiating GetVMSSFromBasicLoadBalancer
[Information]:[GetVMSSFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0' from Azure
[Information]:[GetVMSSFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
[Information]:[BackupBasicLoadBalancer] Initiating Backup of Basic Load Balancer Configurations to path 'c:\serviceFabric'    
[Information]:[BackupBasicLoadBalancer] JSON backup Basic Load Balancer to file c:\serviceFabric\State_LB-sfcluster-nt0_sfcluster_20230115T1745222186.json Completed
[Information]:[BackupBasicLoadBalancer] Exporting Basic Load Balancer ARM template to path 'c:\serviceFabric'...
[Information]:[BackupBasicLoadBalancer] Completed export Basic Load Balancer ARM template to path 'c:\serviceFabric\ARMTemplate_LB-sfcluster-nt0_sfcluster_20230115T1745222186.json'...
[Information]:[BackupBasicLoadBalancer] Attempting to create a file-based backup VMSS with id '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0'
[Information]:[RemoveVMSSPublicIPConfig] Removing Public IP Address configuration from VMSS 
[Information]:[GetVMSSFromBasicLoadBalancer] Initiating GetVMSSFromBasicLoadBalancer
[Information]:[GetVMSSFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0' from Azure
[Information]:[GetVMSSFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
[Information]:[RemoveVMSSPublicIPConfig] Completed removing Public IP Address configuration from VMSS nt0. PIPs removed: 'False'
[Information]:[PublicIPToStatic] Changing public IP addresses to static (if necessary)
WARNING: [Warning]:[PublicIPToStatic] 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') was using Dynamic IP, changing to Static IP allocation method.
[Information]:[PublicIPToStatic] Completed the migration of 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') from Basic SKU and/or dynamic to static
[Information]:[PublicIPToStatic] Public Frontend Migration Completed
[Information]:[RemoveLBFromVMSS] Initiating removal of LB LB-sfcluster-nt0 from VMSS
[Information]:[RemoveLBFromVMSS] Looping all VMSS from Basic Load Balancer LB-sfcluster-nt0
[Information]:[RemoveLBFromVMSS] Building VMSS object from Basic Load Balancer LB-sfcluster-nt0
[Information]:[GetVMSSFromBasicLoadBalancer] Initiating GetVMSSFromBasicLoadBalancer
[Information]:[GetVMSSFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0' from Azure
[Information]:[GetVMSSFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
[Information]:[RemoveLBFromVMSS] Cleaning healthProbe from NetworkProfile of VMSS nt0
[Information]:[RemoveLBFromVMSS] Checking Upgrade Policy Mode of VMSS nt0
[Information]:[RemoveLBFromVMSS] Cleaning LoadBalancerBackendAddressPools from Basic Load Balancer LB-sfcluster-nt0
[Information]:[RemoveLBFromVMSS] Updating VMSS nt0
[Information]:[UpdateVmssInstances] Initiating Update Vmss Instances
[Information]:[UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
[Information]:[UpdateVmssInstances] Update Vmss Instances Completed
[Information]:[RemoveLBFromVMSS] Removing Basic Loadbalancer LB-sfcluster-nt0 from Resource Group sfcluster
[Information]:[RemoveLBFromVMSS] Removal of Basic Loadbalancer LB-sfcluster-nt0 Completed
[Information]:[AddVMSSPublicIPConfig] Adding Public IP Address configuration back to VMSSIP Configs
[Information]:[GetVMSSFromBasicLoadBalancer] Initiating GetVMSSFromBasicLoadBalancer
[Information]:[GetVMSSFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0' from Azure
[Information]:[GetVMSSFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
[Information]:[_CreateStandardLoadBalancer] Initiating Standard Load Balancer Creation
[Information]:[_CreateStandardLoadBalancer] Standard Load Balancer LB-sfcluster-nt0 created successfully
[Information]:[PublicFEMigration] Initiating Public Frontend Migration
WARNING: [Warning]:[PublicFEMigration] 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') is using Basic SKU, changing Standard SKU.
[Information]:[PublicFEMigration] Completed the migration of 'PublicIP-LB-FE-0' ('xxx.xxx.xxx.xxx') from Basic SKU and/or dynamic to static
[Information]:[PublicFEMigration] Saving Standard Load Balancer LB-sfcluster-nt0
[Information]:[PublicFEMigration] Public Frontend Migration Completed
[Information]:[AddLoadBalancerBackendAddressPool] Adding BackendAddressPool LoadBalancerBEAddressPool
[Information]:[AddLoadBalancerBackendAddressPool] Saving added BackendAddressPool to Standard Load Balancer LB-sfcluster-nt0
[Information]:[ProbesMigration] Initiating Probes Migration
[Information]:[ProbesMigration] Adding Probe FabricGatewayProbe to Standard Load Balancer
[Information]:[ProbesMigration] Adding Probe FabricHttpGatewayProbe to Standard Load Balancer
[Information]:[ProbesMigration] Saving Standard Load Balancer LB-sfcluster-nt0
[Information]:[ProbesMigration] Probes Migration Completed
[Information]:[LoadBalacingRulesMigration] Initiating LoadBalacing Rules Migration
[Information]:[LoadBalacingRulesMigration] Adding LoadBalacing Rule LBRule to Standard Load Balancer
[Information]:[LoadBalacingRulesMigration] Adding LoadBalacing Rule LBHttpRule to Standard Load Balancer
[Information]:[LoadBalacingRulesMigration] Saving Standard Load Balancer LB-sfcluster-nt0
[Information]:[LoadBalacingRulesMigration] LoadBalacing Rules Migration Completed
[Information]:[OutboundRulesCreation] Initiating Outbound Rules Creation
[Information]:[OutboundRulesCreation] Adding Outbound Rule LoadBalancerBEAddressPool to Standard Load Balancer
[Information]:[OutboundRulesCreation] Saving Standard Load Balancer LB-sfcluster-nt0
[Information]:[OutboundRulesCreation] Outbound Rules Creation Completed
[Information]:[NatRulesMigration] Initiating Nat Rules Migration
[Information]:[NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.0 to Standard Load Balancer
[Information]:[NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.0' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.0' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
[Information]:[NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.1 to Standard Load Balancer
[Information]:[NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.1' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.1' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
[Information]:[NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.2 to Standard Load Balancer
[Information]:[NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.2' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.2' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
[Information]:[NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.3 to Standard Load Balancer
[Information]:[NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.3' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.3' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
[Information]:[NatRulesMigration] Evaluating adding NAT Rule LoadBalancerBEAddressNatPool.4 to Standard Load Balancer
[Information]:[NatRulesMigration] Checking if the NAT rule has a name that 'LoadBalancerBEAddressNatPool.4' matches an Inbound NAT Pool name with pattern 'LoadBalancerBEAddressNatPool'
WARNING: [Warning]:[NatRulesMigration] NAT Rule 'LoadBalancerBEAddressNatPool.4' appears to have been dynamically created for Inbound NAT Pool 'LoadBalancerBEAddressNatPool'. This rule will not be migrated!
[Information]:[NatRulesMigration] Saving Standard Load Balancer LB-sfcluster-nt0
[Information]:[NatRulesMigration] Nat Rules Migration Completed
[Information]:[InboundNatPoolsMigration] Initiating Inbound NAT Pools Migration
[Information]:[InboundNatPoolsMigration] Adding Inbound NAT Pool LoadBalancerBEAddressNatPool to Standard Load Balancer
[Information]:[InboundNatPoolsMigration] Saving Standard Load Balancer LB-sfcluster-nt0
[Information]:[GetVMSSFromBasicLoadBalancer] Initiating GetVMSSFromBasicLoadBalancer
[Information]:[GetVMSSFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0' from Azure
[Information]:[GetVMSSFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding InboundNATPool to VMSS nt0
[Information]:[_MigrateNetworkInterfaceConfigurations] Checking if VMSS 'nt0' NIC 'NIC-0' IPConfig 'NIC-0' should be associated with NAT Pool 'LoadBalancerBEAddressNatPool'
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding NAT Pool 'LoadBalancerBEAddressNatPool' to IPConfig 'NIC-0'
[Information]:[_MigrateNetworkInterfaceConfigurations] Migrate NetworkInterface Configurations completed
[Information]:[_UpdateAzVmss] Saving VMSS nt0
[Information]:[UpdateVmssInstances] Initiating Update Vmss Instances
[Information]:[UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
[Information]:[UpdateVmssInstances] Update Vmss Instances Completed
[Information]:[InboundNatPoolsMigration] Inbound NAT Pools Migration Completed
[Information]:[NSGCreation] Initiating NSG Creation
[Information]:[NSGCreation] Looping all VMSS in the backend pool of the Load Balancer
[Information]:[NSGCreation] Checking if VMSS Named: nt0 has a NSG
[Information]:[NSGCreation] NSG not detected.
[Information]:[NSGCreation] Creating NSG for VMSS:
[Information]:[NSGCreation] NSG Named: NSG-nt0 created.
[Information]:[NSGCreation] Adding one NSG Rule for each Load Balancing Rule
[Information]:[NSGCreation] Adding NSG Rule Named: LBRule-loadBalancingRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding NSG Rule Named: LBHttpRule-loadBalancingRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding one NSG Rule for each inboundNatRule
[Information]:[NSGCreation] Adding NSG Rule Named: LoadBalancerBEAddressNatPool.0-NatRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding NSG Rule Named: LoadBalancerBEAddressNatPool.1-NatRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding NSG Rule Named: LoadBalancerBEAddressNatPool.2-NatRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding NSG Rule Named: LoadBalancerBEAddressNatPool.3-NatRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding NSG Rule Named: LoadBalancerBEAddressNatPool.4-NatRule to NSG Named: NSG-nt0
[Information]:[NSGCreation] Saving NSG Named: NSG-nt0
[Information]:[NSGCreation] Adding NSG Named: NSG-nt0 to VMSS Named: nt0
[Information]:[NSGCreation] Saving VMSS Named: nt0
[Information]:[UpdateVmssInstances] Initiating Update Vmss Instances
[Information]:[UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
[Information]:[UpdateVmssInstances] Update Vmss Instances Completed
[Information]:[NSGCreation] NSG Creation Completed
[Information]:[BackendPoolMigration] Initiating Backend Pool Migration
[Information]:[BackendPoolMigration] Adding Standard Load Balancer back to the VMSS
[Information]:[BackendPoolMigration] Building VMSS object from Basic Load Balancer LB-sfcluster-nt0[Information]:[GetVMSSFromBasicLoadBalancer] Initiating GetVMSSFromBasicLoadBalancer
[Information]:[GetVMSSFromBasicLoadBalancer] Getting VMSS object '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0' from Azure
[Information]:[GetVMSSFromBasicLoadBalancer] VMSS loaded Name nt0 from RG sfcluster
[Information]:[_MigrateHealthProbe] Migrating Health Probes
[Information]:[_MigrateHealthProbe] Health Probes not found in reference VMSS nt0
[Information]:[_MigrateHealthProbe] Migrating Health Probes completed
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool to VMSS nt0
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
[Information]:[_MigrateNetworkInterfaceConfigurations] Adding BackendAddressPool LoadBalancerBEAddressPool to VMSS Nic: NIC-0 ipConfig: NIC-0
[Information]:[_MigrateNetworkInterfaceConfigurations] Migrate NetworkInterface Configurations completed
[Information]:[UpdateVmss] Updating configuration of VMSS 'nt0'
[Information]:[UpdateVmss] Completed update configuration of VMSS 'nt0'
[Information]:[UpdateVmssInstances] Initiating Update Vmss Instances
[Information]:[UpdateVmssInstances] VMSS 'nt0' is configured with Upgrade Policy 'Automatic', so the update NetworkProfile will be applied automatically.
[Information]:[UpdateVmssInstances] Update Vmss Instances Completed
[Information]:[_RestoreUpgradePolicyMode] Restoring VMSS Upgrade Policy Mode
[Information]:[_RestoreUpgradePolicyMode] VMSS Upgrade Policy Mode not changed
[Information]:[_RestoreUpgradePolicyMode] Restoring VMSS Upgrade Policy Mode completed
[Information]:[UpdateVmss] Updating configuration of VMSS 'nt0'
[Information]:[UpdateVmss] Completed update configuration of VMSS 'nt0'
[Information]:[BackendPoolMigration] Backend Pool Migration Completed
[Information]:############################## Migration Completed ##############################
PS C:\>
```