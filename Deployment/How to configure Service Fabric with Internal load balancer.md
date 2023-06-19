# How to configure Service Fabric with an Internal load balancer

## Overview

The following summarizes the steps required to configure a Service Fabric cluster to use only Internal load balancers. Additional information about this configuration is available [Internal-only load balancer](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking#internal-only-load-balancer). For Service Fabric Managed clusters, refer to [Bring your own Azure Load Balancer](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-networking#bring-your-own-azure-load-balancer) documentation for internal load balancer options.

> ### :exclamation:NOTE: Configuring load balancers with only internal ip addresses may prevent management of cluster resources from cluster view in Azure portal if Service Fabric Resource Provider (SFRP) does not have access. Understand these ramifications and access required before implementing. [Allowing the Service Fabric resource provider to query your cluster](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking#allowing-the-service-fabric-resource-provider-to-query-your-cluster) describes the limitation.

## Steps

### Prerequisites

1. Ensure network connectivity exists for [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) or [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-connect-vm-scale-set) is configured for existing / new private network for management of nodes.
1. If existing ARM template is not available, create a new Service Fabric ARM template from Azure portal and download template **before** deployment. [Service Fabric clusters](https://ms.portal.azure.com/#browse/Microsoft.ServiceFabric%2Fclusters).

### Modify ARM template

Steps for template modification. See [Template Diff](#template-diff) and [Example modified Azure portal template](#example-modified-azure-portal-template) below for example template changes described in steps below.

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

## Example modified Azure portal template

Example template is based on a secure Service Fabric 5 node, 1 nodetype, Silver durability cluster running Windows 2022 Datacenter that has been modififed to use a private IP address. Template is configured to use private static IP address '10.0.0.250'.

```json
{
  "$schema": "http://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "clusterLocation": {
      "type": "string",
      "defaultValue": "",
      "metadata": {
        "description": "Location of the Cluster"
      }
    },
    "clusterName": {
      "type": "string",
      "defaultValue": "GEN-UNIQUE",
      "metadata": {
        "description": "Name of your cluster - Between 3 and 23 characters. Letters and numbers only"
      }
    },
    "nt0applicationStartPort": {
      "type": "int",
      "defaultValue": 20000
    },
    "nt0applicationEndPort": {
      "type": "int",
      "defaultValue": 30000
    },
    "nt0ephemeralStartPort": {
      "type": "int",
      "defaultValue": 49152
    },
    "nt0ephemeralEndPort": {
      "type": "int",
      "defaultValue": 65534
    },
    "nt0fabricTcpGatewayPort": {
      "type": "int",
      "defaultValue": 19000
    },
    "nt0fabricHttpGatewayPort": {
      "type": "int",
      "defaultValue": 19080
    },
    "subnet0Name": {
      "type": "string",
      "defaultValue": "Subnet-0"
    },
    "subnet0Prefix": {
      "type": "string",
      "defaultValue": "10.0.0.0/24"
    },
    "computeLocation": {
      "type": "string"
    },
    "privateIpAddress": {
      "type": "string",
      "defaultValue": "10.0.0.250"
    },
    "privateIPAddressType": {
      "type": "string",
      "allowedValues": [
        "Dynamic",
        "Static"
      ],
      "defaultValue": "Dynamic"
    },
    "adminUserName": {
      "type": "string",
      "defaultValue": "testadm",
      "metadata": {
        "description": "Remote desktop user Id"
      }
    },
    "adminPassword": {
      "type": "securestring",
      "metadata": {
        "description": "Remote desktop user password. Must be a strong password"
      }
    },
    "virtualNetworkName": {
      "type": "string",
      "defaultValue": "VNet"
    },
    "addressPrefix": {
      "type": "string",
      "defaultValue": "10.0.0.0/16"
    },
    "nicName": {
      "type": "string",
      "defaultValue": "NIC"
    },
    "overProvision": {
      "type": "string",
      "defaultValue": "false"
    },
    "vmImagePublisher": {
      "type": "string",
      "defaultValue": "MicrosoftWindowsServer",
      "metadata": {
        "description": "VM image Publisher"
      }
    },
    "vmImageOffer": {
      "type": "string",
      "defaultValue": "WindowsServer",
      "metadata": {
        "description": "VM image offer"
      }
    },
    "vmImageSku": {
      "type": "string",
      "defaultValue": "2022-Datacenter",
      "metadata": {
        "description": "VM image SKU"
      }
    },
    "vmImageVersion": {
      "type": "string",
      "defaultValue": "latest",
      "metadata": {
        "description": "VM image version"
      }
    },
    "sourceVaultValue": {
      "type": "string",
      "defaultValue": "GEN-KEYVAULT-RESOURCE-ID",
      "metadata": {
        "description": "Resource Id of the key vault, is should be in the format of /subscriptions/<Sub ID>/resourceGroups/<Resource group name>/providers/Microsoft.KeyVault/vaults/<vault name>"
      }
    },
    "certificateUrlValue": {
      "type": "string",
      "defaultValue": "GEN-KEYVAULT-SSL-SECRET-URI",
      "metadata": {
        "description": "Refers to the location URL in your key vault where the certificate was uploaded, it is should be in the format of https://<name of the vault>.vault.azure.net:443/secrets/<exact location>"
      }
    },
    "clusterProtectionLevel": {
      "type": "string",
      "allowedValues": [
        "None",
        "Sign",
        "EncryptAndSign"
      ],
      "defaultValue": "EncryptAndSign",
      "metadata": {
        "description": "Protection level.Three values are allowed - EncryptAndSign, Sign, None. It is best to keep the default of EncryptAndSign, unless you have a need not to"
      }
    },
    "certificateStoreValue": {
      "type": "string",
      "allowedValues": [
        "My"
      ],
      "defaultValue": "My",
      "metadata": {
        "description": "The store name where the cert will be deployed in the virtual machine"
      }
    },
    "certificateThumbprint": {
      "type": "string",
      "defaultValue": "GEN-CUSTOM-DOMAIN-SSLCERT-THUMBPRINT",
      "metadata": {
        "description": "Certificate Thumbprint"
      }
    },
    "storageAccountType": {
      "type": "string",
      "allowedValues": [
        "Standard_LRS",
        "Standard_GRS"
      ],
      "defaultValue": "Standard_LRS",
      "metadata": {
        "description": "Replication option for the VM image storage account"
      }
    },
    "supportLogStorageAccountType": {
      "type": "string",
      "allowedValues": [
        "Standard_LRS",
        "Standard_GRS"
      ],
      "defaultValue": "Standard_LRS",
      "metadata": {
        "description": "Replication option for the support log storage account"
      }
    },
    "supportLogStorageAccountName": {
      "type": "string",
      "defaultValue": "[toLower( concat('sflogs', uniqueString(resourceGroup().id),'2'))]",
      "metadata": {
        "description": "Name for the storage account that contains support logs from the cluster"
      }
    },
    "applicationDiagnosticsStorageAccountType": {
      "type": "string",
      "allowedValues": [
        "Standard_LRS",
        "Standard_GRS"
      ],
      "defaultValue": "Standard_LRS",
      "metadata": {
        "description": "Replication option for the application diagnostics storage account"
      }
    },
    "applicationDiagnosticsStorageAccountName": {
      "type": "string",
      "defaultValue": "[toLower(concat('wad',uniqueString(resourceGroup().id), '3' ))]",
      "metadata": {
        "description": "Name for the storage account that contains application diagnostics data from the cluster"
      }
    },
    "nt0InstanceCount": {
      "type": "int",
      "defaultValue": 5,
      "metadata": {
        "description": "Instance count for node type"
      }
    },
    "vmNodeType0Name": {
      "type": "string",
      "defaultValue": "nt0",
      "maxLength": 9
    },
    "vmNodeType0Size": {
      "type": "string",
      "defaultValue": "Standard_D2_v2"
    }
  },
  "variables": {
    "vmssApiVersion": "2017-03-30",
    "lbApiVersion": "2015-06-15",
    "vNetApiVersion": "2015-06-15",
    "storageApiVersion": "2019-04-01",
    "vnetID": "[resourceId('Microsoft.Network/virtualNetworks',parameters('virtualNetworkName'))]",
    "subnet0Ref": "[concat(variables('vnetID'),'/subnets/',parameters('subnet0Name'))]",
    "lbID0": "[resourceId('Microsoft.Network/loadBalancers', concat('LB','-', parameters('clusterName'),'-',parameters('vmNodeType0Name')))]",
    "lbIPConfig0": "[concat(variables('lbID0'),'/frontendIPConfigurations/LoadBalancerIPConfig')]",
    "lbPoolID0": "[concat(variables('lbID0'),'/backendAddressPools/LoadBalancerBEAddressPool')]",
    "lbProbeID0": "[concat(variables('lbID0'),'/probes/FabricGatewayProbe')]",
    "lbHttpProbeID0": "[concat(variables('lbID0'),'/probes/FabricHttpGatewayProbe')]",
    "lbNatPoolID0": "[concat(variables('lbID0'),'/inboundNatPools/LoadBalancerBEAddressNatPool')]"
  },
  "resources": [
    {
      "apiVersion": "[variables('storageApiVersion')]",
      "type": "Microsoft.Storage/storageAccounts",
      "name": "[parameters('supportLogStorageAccountName')]",
      "location": "[parameters('computeLocation')]",
      "dependsOn": [],
      "properties": {
        "allowBlobPublicAccess": false
      },
      "kind": "Storage",
      "sku": {
        "name": "[parameters('supportLogStorageAccountType')]"
      },
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "[parameters('clusterName')]"
      }
    },
    {
      "apiVersion": "[variables('storageApiVersion')]",
      "type": "Microsoft.Storage/storageAccounts",
      "name": "[parameters('applicationDiagnosticsStorageAccountName')]",
      "location": "[parameters('computeLocation')]",
      "dependsOn": [],
      "properties": {
        "allowBlobPublicAccess": false
      },
      "kind": "Storage",
      "sku": {
        "name": "[parameters('applicationDiagnosticsStorageAccountType')]"
      },
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "[parameters('clusterName')]"
      }
    },
    {
      "apiVersion": "[variables('vNetApiVersion')]",
      "type": "Microsoft.Network/virtualNetworks",
      "name": "[parameters('virtualNetworkName')]",
      "location": "[parameters('computeLocation')]",
      "dependsOn": [],
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
              "addressPrefix": "[parameters('subnet0Prefix')]"
            }
          }
        ]
      },
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "[parameters('clusterName')]"
      }
    },
    {
      "apiVersion": "[variables('lbApiVersion')]",
      "type": "Microsoft.Network/loadBalancers",
      "name": "[concat('LB','-', parameters('clusterName'),'-',parameters('vmNodeType0Name'))]",
      "location": "[parameters('computeLocation')]",
      "dependsOn": [
      ],
      "properties": {
        "frontendIPConfigurations": [
          {
            "name": "LoadBalancerIPConfig",
            "properties": {
              "subnet": {
                "id": "[variables('subnet0Ref')]"
              },
              "privateIPAddress": "[parameters('privateIpAddress')]",
              "privateIPAllocationMethod": "[parameters('privateIPAddressType')]"
            }
          }
        ],
        "backendAddressPools": [
          {
            "name": "LoadBalancerBEAddressPool",
            "properties": {}
          }
        ],
        "loadBalancingRules": [
          {
            "name": "LBRule",
            "properties": {
              "backendAddressPool": {
                "id": "[variables('lbPoolID0')]"
              },
              "backendPort": "[parameters('nt0fabricTcpGatewayPort')]",
              "enableFloatingIP": "false",
              "frontendIPConfiguration": {
                "id": "[variables('lbIPConfig0')]"
              },
              "frontendPort": "[parameters('nt0fabricTcpGatewayPort')]",
              "idleTimeoutInMinutes": "5",
              "probe": {
                "id": "[variables('lbProbeID0')]"
              },
              "protocol": "tcp"
            }
          },
          {
            "name": "LBHttpRule",
            "properties": {
              "backendAddressPool": {
                "id": "[variables('lbPoolID0')]"
              },
              "backendPort": "[parameters('nt0fabricHttpGatewayPort')]",
              "enableFloatingIP": "false",
              "frontendIPConfiguration": {
                "id": "[variables('lbIPConfig0')]"
              },
              "frontendPort": "[parameters('nt0fabricHttpGatewayPort')]",
              "idleTimeoutInMinutes": "5",
              "probe": {
                "id": "[variables('lbHttpProbeID0')]"
              },
              "protocol": "tcp"
            }
          }
        ],
        "probes": [
          {
            "name": "FabricGatewayProbe",
            "properties": {
              "intervalInSeconds": 5,
              "numberOfProbes": 2,
              "port": "[parameters('nt0fabricTcpGatewayPort')]",
              "protocol": "tcp"
            }
          },
          {
            "name": "FabricHttpGatewayProbe",
            "properties": {
              "intervalInSeconds": 5,
              "numberOfProbes": 2,
              "port": "[parameters('nt0fabricHttpGatewayPort')]",
              "protocol": "tcp"
            }
          }
        ],
        "inboundNatPools": [
          {
            "name": "LoadBalancerBEAddressNatPool",
            "properties": {
              "backendPort": "3389",
              "frontendIPConfiguration": {
                "id": "[variables('lbIPConfig0')]"
              },
              "frontendPortRangeEnd": "4500",
              "frontendPortRangeStart": "3389",
              "protocol": "tcp"
            }
          }
        ]
      },
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "[parameters('clusterName')]"
      }
    },
    {
      "apiVersion": "[variables('vmssApiVersion')]",
      "type": "Microsoft.Compute/virtualMachineScaleSets",
      "name": "[parameters('vmNodeType0Name')]",
      "location": "[parameters('computeLocation')]",
      "dependsOn": [
        "[concat('Microsoft.Network/virtualNetworks/', parameters('virtualNetworkName'))]",
        "[concat('Microsoft.Network/loadBalancers/', concat('LB','-', parameters('clusterName'),'-',parameters('vmNodeType0Name')))]",
        "[concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName'))]",
        "[concat('Microsoft.Storage/storageAccounts/', parameters('applicationDiagnosticsStorageAccountName'))]"
      ],
      "properties": {
        "overprovision": "[parameters('overProvision')]",
        "upgradePolicy": {
          "mode": "Automatic"
        },
        "virtualMachineProfile": {
          "extensionProfile": {
            "extensions": [
              {
                "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
                "properties": {
                  "type": "ServiceFabricNode",
                  "autoUpgradeMinorVersion": true,
                  "protectedSettings": {
                    "StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key1]",
                    "StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key2]"
                  },
                  "publisher": "Microsoft.Azure.ServiceFabric",
                  "settings": {
                    "clusterEndpoint": "[reference(parameters('clusterName')).clusterEndpoint]",
                    "nodeTypeRef": "[parameters('vmNodeType0Name')]",
                    "dataPath": "D:\\\\SvcFab",
                    "durabilityLevel": "Silver",
                    "enableParallelJobs": true,
                    "nicPrefixOverride": "[parameters('subnet0Prefix')]",
                    "certificate": {
                      "thumbprint": "[parameters('certificateThumbprint')]",
                      "x509StoreName": "[parameters('certificateStoreValue')]"
                    }
                  },
                  "typeHandlerVersion": "1.1"
                }
              },
              {
                "name": "[concat('VMDiagnosticsVmExt','_vmNodeType0Name')]",
                "properties": {
                  "type": "IaaSDiagnostics",
                  "autoUpgradeMinorVersion": true,
                  "protectedSettings": {
                    "storageAccountName": "[parameters('applicationDiagnosticsStorageAccountName')]",
                    "storageAccountKey": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('applicationDiagnosticsStorageAccountName')),'2015-05-01-preview').key1]",
                    "storageAccountEndPoint": "https://core.windows.net/"
                  },
                  "publisher": "Microsoft.Azure.Diagnostics",
                  "settings": {
                    "WadCfg": {
                      "DiagnosticMonitorConfiguration": {
                        "overallQuotaInMB": "50000",
                        "EtwProviders": {
                          "EtwEventSourceProviderConfiguration": [
                            {
                              "provider": "Microsoft-ServiceFabric-Actors",
                              "scheduledTransferKeywordFilter": "1",
                              "scheduledTransferPeriod": "PT5M",
                              "DefaultEvents": {
                                "eventDestination": "ServiceFabricReliableActorEventTable"
                              }
                            },
                            {
                              "provider": "Microsoft-ServiceFabric-Services",
                              "scheduledTransferPeriod": "PT5M",
                              "DefaultEvents": {
                                "eventDestination": "ServiceFabricReliableServiceEventTable"
                              }
                            }
                          ],
                          "EtwManifestProviderConfiguration": [
                            {
                              "provider": "cbd93bc2-71e5-4566-b3a7-595d8eeca6e8",
                              "scheduledTransferLogLevelFilter": "Information",
                              "scheduledTransferKeywordFilter": "4611686018427387904",
                              "scheduledTransferPeriod": "PT5M",
                              "DefaultEvents": {
                                "eventDestination": "ServiceFabricSystemEventTable"
                              }
                            }
                          ]
                        }
                      }
                    },
                    "StorageAccount": "[parameters('applicationDiagnosticsStorageAccountName')]"
                  },
                  "typeHandlerVersion": "1.5"
                }
              }
            ]
          },
          "networkProfile": {
            "networkInterfaceConfigurations": [
              {
                "name": "[concat(parameters('nicName'), '-0')]",
                "properties": {
                  "ipConfigurations": [
                    {
                      "name": "[concat(parameters('nicName'),'-',0)]",
                      "properties": {
                        "loadBalancerBackendAddressPools": [
                          {
                            "id": "[variables('lbPoolID0')]"
                          }
                        ],
                        "loadBalancerInboundNatPools": [
                          {
                            "id": "[variables('lbNatPoolID0')]"
                          }
                        ],
                        "subnet": {
                          "id": "[variables('subnet0Ref')]"
                        }
                      }
                    }
                  ],
                  "primary": true
                }
              }
            ]
          },
          "osProfile": {
            "adminPassword": "[parameters('adminPassword')]",
            "adminUsername": "[parameters('adminUsername')]",
            "computernamePrefix": "[parameters('vmNodeType0Name')]",
            "secrets": [
              {
                "sourceVault": {
                  "id": "[parameters('sourceVaultValue')]"
                },
                "vaultCertificates": [
                  {
                    "certificateStore": "[parameters('certificateStoreValue')]",
                    "certificateUrl": "[parameters('certificateUrlValue')]"
                  }
                ]
              }
            ]
          },
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
              "managedDisk": {
                "storageAccountType": "[parameters('storageAccountType')]"
              }
            }
          }
        }
      },
      "sku": {
        "name": "[parameters('vmNodeType0Size')]",
        "capacity": "[parameters('nt0InstanceCount')]",
        "tier": "Standard"
      },
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "[parameters('clusterName')]"
      }
    },
    {
      "apiVersion": "2018-02-01",
      "type": "Microsoft.ServiceFabric/clusters",
      "name": "[parameters('clusterName')]",
      "location": "[parameters('clusterLocation')]",
      "dependsOn": [
        "[concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName'))]"
      ],
      "properties": {
        "addonFeatures": [
          "DnsService"
        ],
        "azureActiveDirectory": {
          "clientApplication": "72531d17-43e1-40b7-8999-b7d2f150e84a",
          "clusterApplication": "72531d17-43e1-40b7-8999-b7d2f150e84a",
          "tenantId": "72531d17-43e1-40b7-8999-b7d2f150e84a"
        },
        "certificate": {
          "thumbprint": "[parameters('certificateThumbprint')]",
          "x509StoreName": "[parameters('certificateStoreValue')]"
        },
        "clientCertificateCommonNames": [],
        "clientCertificateThumbprints": [],
        "clusterState": "Default",
        "diagnosticsStorageAccountConfig": {
          "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.blob]",
          "protectedAccountKeyName": "StorageAccountKey1",
          "queueEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.queue]",
          "storageAccountName": "[parameters('supportLogStorageAccountName')]",
          "tableEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.table]"
        },
        "fabricSettings": [
          {
            "parameters": [
              {
                "name": "ClusterProtectionLevel",
                "value": "[parameters('clusterProtectionLevel')]"
              }
            ],
            "name": "Security"
          }
        ],
        "managementEndpoint": "[concat('https://',reference(variables('lbID0')).frontEndIPConfigurations[0].properties.privateIPAddress,':',parameters('nt0fabricHttpGatewayPort'))]",
        "nodeTypes": [
          {
            "name": "[parameters('vmNodeType0Name')]",
            "applicationPorts": {
              "endPort": "[parameters('nt0applicationEndPort')]",
              "startPort": "[parameters('nt0applicationStartPort')]"
            },
            "clientConnectionEndpointPort": "[parameters('nt0fabricTcpGatewayPort')]",
            "durabilityLevel": "Silver",
            "ephemeralPorts": {
              "endPort": "[parameters('nt0ephemeralEndPort')]",
              "startPort": "[parameters('nt0ephemeralStartPort')]"
            },
            "httpGatewayEndpointPort": "[parameters('nt0fabricHttpGatewayPort')]",
            "isPrimary": true,
            "vmInstanceCount": "[parameters('nt0InstanceCount')]"
          }
        ],
        "provisioningState": "Default",
        "reliabilityLevel": "Silver",
        "upgradeMode": "Automatic",
        "vmImage": "Windows"
      },
      "tags": {
        "resourceType": "Service Fabric",
        "clusterName": "[parameters('clusterName')]"
      }
    }
  ],
  "outputs": {
    "clusterProperties": {
      "value": "[reference(parameters('clusterName'))]",
      "type": "object"
    }
  }
}

```
