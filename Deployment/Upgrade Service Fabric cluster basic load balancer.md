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

#### **Public IP addresses changes**

```diff
   "resources": [
     {
       "type": "Microsoft.Network/publicIPAddresses",
       "apiVersion": "2022-05-01",
       "name": "[parameters('publicIPAddresses_PublicIP_LB_FE_0_name')]",
       "comments": "Generalized from resource: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Network/publicIPAddresses/PublicIP-LB-FE-0'.",
       "location": "eastus",
       "tags": {
         "resourceType": "Service Fabric",
         "clusterName": "sfcluster"
       },
       "sku": {
-        "name": "Basic",
+        "name": "Standard",
         "tier": "Regional"
       },
       "properties": {
         "ipAddress": "xxx.xxx.xxx.xxx",
         "publicIPAddressVersion": "IPv4",
-        "publicIPAllocationMethod": "Dynamic",
+        "publicIPAllocationMethod": "Static",
         "idleTimeoutInMinutes": 4,
         "dnsSettings": {
           "domainNameLabel": "sfcluster",
           "fqdn": "sfcluster.eastus.cloudapp.azure.com"
         },
-        "ipTags": []
+        "ipTags": [],
+        "ddosSettings": {
+          "protectionMode": "VirtualNetworkInherited"
+        }
       }
     },
```

#### **Virtual machine scale set changes**

```diff
   "resources": [
     {
      "type": "Microsoft.Compute/virtualMachineScaleSets",
      "apiVersion": "2022-08-01",
      "name": "[parameters('virtualMachineScaleSets_nt0_name')]",
      "comments": "Generalized from resource: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Compute/virtualMachineScaleSets/nt0'.",
      "location": "eastus",
      "dependsOn": [
        "[resourceId('Microsoft.Network/virtualNetworks/', parameters('virtualNetworks_VNet_name'))]",
        "[resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name'))]"
      ],
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "sfcluster"
      },
      "sku": {
        "name": "Standard_D2_v2",
        "tier": "Standard",
        "capacity": 5
      },
      "properties": {
        "singlePlacementGroup": true,
        "orchestrationMode": "Uniform",
        "upgradePolicy": {
          "mode": "Automatic"
        },
        "virtualMachineProfile": {
...
        "networkProfile": {
             "networkInterfaceConfigurations": [
               {
                 "name": "NIC-0",
                 "properties": {
                   "primary": true,
                   "enableAcceleratedNetworking": false,
                   "disableTcpStateTracking": false,
+                  "networkSecurityGroup": {
+                    "id": "[parameters('networkSecurityGroups_NSG_nt0_externalid')]"
+                  },
```

#### **Load balancer changes**

```diff
   "resources": [
     {
       "type": "Microsoft.Network/loadBalancers",
       "apiVersion": "2022-05-01",
       "name": "[parameters('loadBalancers_LB_sfcluster_nt0_name')]",
       "comments": "Generalized from resource: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sfcluster/providers/Microsoft.Network/loadBalancers/LB-sfcluster-nt0'.",
       "location": "eastus",
       "dependsOn": [
         "[resourceId('Microsoft.Network/publicIPAddresses', parameters('publicIPAddresses_PublicIP_LB_FE_0_name'))]"
       ],
-      "tags": {
-        "resourceType": "Service Fabric",
-        "clusterName": "sfcluster"
-      },
       "sku": {
-        "name": "Basic",
+        "name": "Standard",
         "tier": "Regional"
       },
       "properties": {
         "frontendIPConfigurations": [
           {
             "name": "LoadBalancerIPConfig",
             "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/frontendIPConfigurations/LoadBalancerIPConfig')]",
             "properties": {
               "privateIPAllocationMethod": "Dynamic",
               "publicIPAddress": {
                 "id": "[resourceId('Microsoft.Network/publicIPAddresses', parameters('publicIPAddresses_PublicIP_LB_FE_0_name'))]"
               }
             }
           }
         ],
         "backendAddressPools": [
           {
             "name": "LoadBalancerBEAddressPool",
             "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('loadBalancers_LB_sfcluster_nt0_name'), 'LoadBalancerBEAddressPool')]",
-            "properties": {}
+            "properties": {
+              "loadBalancerBackendAddresses": [
+                {
+                  "name": "sfcluster_nt0_virtualMachines_0_networkInterfaces_NIC-0NIC-0",
+                  "properties": {}
+                },
+                {
+                  "name": "sfcluster_nt0_virtualMachines_1_networkInterfaces_NIC-0NIC-0",
+                  "properties": {}
+                },
+                {
+                  "name": "sfcluster_nt0_virtualMachines_2_networkInterfaces_NIC-0NIC-0",
+                  "properties": {}
+                },
+                {
+                  "name": "sfcluster_nt0_virtualMachines_3_networkInterfaces_NIC-0NIC-0",
+                  "properties": {}
+                },
+                {
+                  "name": "sfcluster_nt0_virtualMachines_4_networkInterfaces_NIC-0NIC-0",
+                  "properties": {}
+                }
+              ]
+            }
           }
         ],
         "loadBalancingRules": [
           {
             "name": "LBRule",
             "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/loadBalancingRules/LBRule')]",
             "properties": {
               "frontendIPConfiguration": {
                 "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/frontendIPConfigurations/LoadBalancerIPConfig')]"
               },
               "frontendPort": 19000,
               "backendPort": 19000,
               "enableFloatingIP": false,
               "idleTimeoutInMinutes": 5,
               "protocol": "Tcp",
               "enableTcpReset": false,
               "loadDistribution": "Default",
+              "disableOutboundSnat": true,
               "backendAddressPool": {
                 "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('loadBalancers_LB_sfcluster_nt0_name'), 'LoadBalancerBEAddressPool')]"
               },
               "backendAddressPools": [
                 {
                   "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('loadBalancers_LB_sfcluster_nt0_name'), 'LoadBalancerBEAddressPool')]"
                 }
               ],
               "probe": {
                 "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/probes/FabricGatewayProbe')]"
               }
             }
           },
           {
             "name": "LBHttpRule",
             "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/loadBalancingRules/LBHttpRule')]",
             "properties": {
               "frontendIPConfiguration": {
                 "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/frontendIPConfigurations/LoadBalancerIPConfig')]"
               },
               "frontendPort": 19080,
               "backendPort": 19080,
               "enableFloatingIP": false,
               "idleTimeoutInMinutes": 5,
               "protocol": "Tcp",
               "enableTcpReset": false,
               "loadDistribution": "Default",
+              "disableOutboundSnat": true,
               "backendAddressPool": {
                 "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('loadBalancers_LB_sfcluster_nt0_name'), 'LoadBalancerBEAddressPool')]"
               },
               "backendAddressPools": [
                 {
                   "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('loadBalancers_LB_sfcluster_nt0_name'), 'LoadBalancerBEAddressPool')]"
                 }
               ],
               "probe": {
                 "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/probes/FabricHttpGatewayProbe')]"
               }
             }
           }
         ],
...
+        "outboundRules": [
+          {
+            "name": "LoadBalancerBEAddressPool",
+            "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/outboundRules/LoadBalancerBEAddressPool')]",
+            "properties": {
+              "allocatedOutboundPorts": 0,
+              "protocol": "All",
+              "enableTcpReset": true,
+              "idleTimeoutInMinutes": 4,
+              "backendAddressPool": {
+                "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', parameters('loadBalancers_LB_sfcluster_nt0_name'), 'LoadBalancerBEAddressPool')]"
+              },
+              "frontendIPConfigurations": [
+                {
+                  "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('loadBalancers_LB_sfcluster_nt0_name')), '/frontendIPConfigurations/LoadBalancerIPConfig')]"
+                }
+              ]
+            }
+          }
+        ],
```

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