# How to configure Log Analytics for Service Fabric clusters

## Introduction

This article describes how to setup Log Analytics for Service Fabric Cluster. With Log Analytics, you can collect and analyze the logs of your Service Fabric Cluster. You can also setup alerts based on the logs. 

Service Fabric Managed clusters have built-in support for Log Analytics. For more information, see [Azure Service Fabric Managed Clusters](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-managed-clusters).

## Prerequisites

- You have a Service Fabric Cluster running in Azure.
- You have a Log Analytics workspace created in Azure. For more information, see [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-quick-create-workspace).

## Setup Log Analytics for Service Fabric Cluster

1. Ensure Windows Azure Diagnostics (WAD) extension is configured on the nodetypes / scale sets. The WadCfg has the configuration for collection and storage account where WAD table data is stored. See [Event Aggregation with Windows Azure Diagnostics - Azure Service Fabric | Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-aggregation-wad) for more information.

    Example WadCfg Extension ARM template configuration:

    <details><summary>Click to expand</summary>

    ```json
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
                    },
                    {
                        "provider": "02d06793-efeb-48c8-8f7f-09713309a810",
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
    ```

    </details>

1. Validate that the WAD extension data is being uploaded to the storage account 'WADServiceFabric*Table' Tables. Service Fabric clusters with WAD enabled typically deploy with two storage accounts. One is for Service Fabric cluster logging that contains only blob data. The other is for WAD events that are stored in table data only. If unsure which account is being used, the storage account is configured in the WadCfg as shown above in property 'StorageAccount'. You can use [Azure Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) to view the data in the storage account. Azure Portal can be used to see if the tables have been created.

    Example:

    ![WAD Tables](/media/how-to-configure-log-analytics-for-service-fabric-clusters/azure-portal-storage-wad-tables.png)

1. Open the Log Analytics workspace in Azure portal. If a workspace has not been created, see [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/azure/log-analytics/log-analytics-quick-create-workspace).

1. Select 'Legacy storage account logs' and add the Service Fabric WAD storage account to the workspace.
  
    ![Add Storage Account](/media/how-to-configure-log-analytics-for-service-fabric-clusters/azure-portal-log-analytics-add-storage-account.png)

1. Select '+ Add' to add the Service Fabric application diagnostics storage account. This account has the 'WADServiceFabric*EventTable' tables as shown in example above.

1. For 'Data Type', select 'Service Fabric Events' from the drop-down menu. The 'Source' will populate automatically with 'WADServiceFabric*EventTable'.

    ![Add Storage Account](/media/how-to-configure-log-analytics-for-service-fabric-clusters/azure-portal-log-analytics-add-storage-account-data-type.png)

1. Select 'Save' to save the changes.

## Verification

After configuration, you can verify that the Service Fabric events are being collected by Log Analytics by running 'search *' in Log Analytics 'Logs' view.

> **Note:**
> Data may take a few minutes to appear in Log Analytics.

1. Open Log Analytics workspace in Azure portal. [Log Analytics workspaces - Microsoft Azure](https://ms.portal.azure.com/#browse/Microsoft.OperationalInsights%2Fworkspaces)
  
1. Select 'Logs', enter a generic query like 'search *' and verify 'Time range'. There should be recent events and under 'LogManagement' there should be 'ServiceFabricOperationalEvent' and 'ServiceFabricReliableServiceEvent' tables.

    ![Log Analytics Search](/media/how-to-configure-log-analytics-for-service-fabric-clusters/azure-portal-log-analytics-search.png)

## Troubleshooting

