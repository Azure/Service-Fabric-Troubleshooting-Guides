# How to Rotate Access Keys of Storage Account for Service Fabric logs

This troubleshooting guide describes the steps to rotate Storage Account Keys for the storage account used for Service Fabric Logs. This guide is applicable for Service Fabric clusters only. Service Fabric Managed clusters do not use storage account keys for Service Fabric logs.

Best practice is to provision and manage Service Fabric clusters using ARM templates. This guide describes the steps to rotate Storage Account Keys using ARM templates. If you are not using ARM templates to provision and manage Service Fabric clusters, you can use [resources.azure.com](https://resources.azure.com) to modify the Service Fabric resource to rotate Storage Account Keys.

## Modify using ARM Template

### Validate current configuration

Use the following steps to validate current configuration of Service Fabric resource and VMSS extensions. Use [Microsoft.Compute virtualMachineScaleSets](https://learn.microsoft.com/azure/templates/microsoft.compute/virtualmachinescalesets) and [Microsoft.ServiceFabric clusters](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/clusters) for reference.

1. For each Nodetype / Virtual Machine Scale Set (VMSS), verify current Service Fabric extension storage configuration.
    * In the Service Fabric VM Extension section, verify there are two storage keys configured and 'StorageAccountKey2' refers to key2 of storage account. If configured with only one key 'StorageAccountKey1', add a second key 'StorageAccountKey2'.

        ```json
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
        ...
        ```

2. Verify current active Storage Account Key configuration for Service Fabric resource.

    This can be verified by looking at 'protectedAccountKeyName' in 'diagnosticsStorageAccountConfig' section under Service Fabric resource of the ARM template. If configured with only 'protectedAccountKeyName' add 'protectedAccountName2' for inactive / fallback storage account key.

    > [!NOTE]
    > Modifying the Service Fabric resource requires a full cluster Upgrade Domain (UD) walk.

    ```json
    {
        "apiVersion": "2020-03-01",
        "type": "Microsoft.ServiceFabric/clusters",
        "name": "[parameters('clusterName')]",
        "location": "[parameters('clusterLocation')]",
        "dependsOn": [
            "[concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName'))]"
        ],
        "properties": {
            "addOnFeatures": [
                "DnsService",
                "RepairManager"
            ],
            "certificate": {
                "thumbprint": "[parameters('certificateThumbprint')]",
                "x509StoreName": "[parameters('certificateStoreValue')]"
            },
            "clientCertificateCommonNames": [],
            "clientCertificateThumbprints": [],
            "clusterState": "Default",
            "diagnosticsStorageAccountConfig": {
                "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.blob]",
                "protectedAccountKeyName": "StorageAccountKey1", // <--- current active storage account key
                "protectedAccountKeyName2": "StorageAccountKey2", // <--- current inactive / fallback storage account key
                "queueEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.queue]",
                "storageAccountName": "[parameters('supportLogStorageAccountName')]",
                "tableEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.table]"
            },
    ```

### Setting inactive storage account key

1. Rotate inactive Storage Account Key. In this guide, 'StorageAccountKey2'/'key2' of storage account is inactive.

    Rotate 'StorageAccountKey2'/'key2' of storage account using by clicking 'Rotate key' in the storage account 'Access Keys'. See [Manually Rotate Access Keys](https://learn.microsoft.com/azure/storage/common/storage-account-keys-manage?tabs=azure-portal#manually-rotate-access-keys") for detailed steps.

    ![Storage Account Keys](../media/storage-account-access-keys.png)

1. After rotation, choose one of these actions to update Service Fabric resource to point to  new 'StorageAccountKey2'.

    * **Parameterized template:** If template property value is parameterized as shown below, verify 'supportLogStorageAccountName' and redeploy template in incremental mode.

        ```json
            "protectedSettings": {
            "StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key1]",
            "StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key2]"
        },
        ```

    * **Non-parameterized template:** Else, if template property value is not parameterized, use updated 'StorageAccountKey2' from storage account and modify 'diagnosticsStorageAccountConfig' section of  Service Fabric resource. Redeploy template in incremental mode.

        ```diff
            "protectedSettings": {
            "StorageAccountKey1": "<StorageAccountKey1>",
        -   "StorageAccountKey2": "<(old) StorageAccountKey2>"
        +   "StorageAccountKey2": "<(new) StorageAccountKey2>"
        },
        ```

1. **Optional:** To verify configuration, set the value of 'protectedAccountKeyName' to 'StorageAccountKey2' in 'diagnosticsStorageAccountConfig' section of the Service Fabric resource, while keeping the rest unchanged.

    ```diff
    "diagnosticsStorageAccountConfig": {
        "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.blob]",
    -       "protectedAccountKeyName": "StorageAccountKey1",
    +       "protectedAccountKeyName": "StorageAccountKey2",
    -       "protectedAccountKeyName2": "StorageAccountKey2",
    +       "protectedAccountKeyName2": "StorageAccountKey1",
    ```

1. Deploy the ARM template to update the Service Fabric resource.

    ```powershell
    New-AzResourceGroupDeployment -ResourceGroupName '<resource group name>' `
        -TemplateFile '<template file path>' `
        -TemplateParameterFile '<template parameter file path>' `
        -Mode Incremental
    ```

1. After template updates have been deployed, verify successful configuration by reviewing cluster state in Service Fabric Explorer. The cluster nodes should not have any new warnings or errors related to the storage account. Additionally, selecting the 'Events' tab for the cluster in SFX should show a new event with the following message: "Storage account key rotation completed successfully".

### Setting active storage account key

1. Rotate active Storage Account Key. In this guide, 'StorageAccountKey1'/'key1' of storage account is active.

    Rotate 'StorageAccountKey1'/'key1' of storage account using by clicking 'Rotate key' in the storage account 'Access Keys'. See [Manually Rotate Access Keys](https://learn.microsoft.com/azure/storage/common/storage-account-keys-manage?tabs=azure-portal#manually-rotate-access-keys") for detailed steps.

    ![Storage Account Keys](../media/storage-account-access-keys.png)

1. After rotation, choose one of these actions to update Service Fabric resource to point to  new 'StorageAccountKey1'.

    * **Parameterized template:** If template property value is parameterized as shown below, verify 'supportLogStorageAccountName' and redeploy template in incremental mode.

        ```json
            "protectedSettings": {
            "StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key1]",
            "StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key2]"
        },
        ```

    * **Non-parameterized template:** Else, if template property value is not parameterized, use updated 'StorageAccountKey1' from storage account and modify 'diagnosticsStorageAccountConfig' section of  Service Fabric resource. Redeploy template in incremental mode.

        ```diff
            "protectedSettings": {
        -   "StorageAccountKey1": "<(old) StorageAccountKey1>"
        +   "StorageAccountKey1": "<(new) StorageAccountKey1>"
            "StorageAccountKey2": "<StorageAccountKey2>",
        },
        ```

1. **Optional:** To verify configuration, set the value of 'protectedAccountKeyName' to 'StorageAccountKey1' in 'diagnosticsStorageAccountConfig' section of the Service Fabric resource, while keeping the rest unchanged.

    ```diff
    "diagnosticsStorageAccountConfig": {
        "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.blob]",
    -       "protectedAccountKeyName": "StorageAccountKey2",
    +       "protectedAccountKeyName": "StorageAccountKey1",
    -       "protectedAccountKeyName2": "StorageAccountKey2",
    +       "protectedAccountKeyName2": "StorageAccountKey1",
    ```

1. Deploy the ARM template to update the Service Fabric resource.

    ```powershell
    New-AzResourceGroupDeployment -ResourceGroupName '<resource group name>' `
        -TemplateFile '<template file path>' `
        -TemplateParameterFile '<template parameter file path>' `
        -Mode Incremental
    ```

1. After template updates have been deployed, verify successful configuration by reviewing cluster state in Service Fabric Explorer. The cluster nodes should not have any new warnings or errors related to the storage account.

## Modify using resources.azure.com

1. In <https://resources.azure.com>, navigate to the virtual machine scale set configured for the cluster:

    ```text
        subscriptions
        └───%subscription name%
            └───resourceGroups
                └───%resource group name%
                    └───providers
                        └───Microsoft.Compute
                            └───virtualMachineScaleSets
                                └───%virtual machine scale set name%
    ```

    ![Azure Resource Explorer](../media/resourcemgr1.png)

1. Click "Read/Write" permission and "Edit" to edit configuration.

    ![Read/Write](../media/resourcemgr3.png)  
    ![Edit](../media/resourcemgr2.png)

1. Navigate to '/properties/virtualMachineProfile/extensionProfile/extensions' and add 'protectedSettings' section. Replace '\<StorageAccountKey1>' and '\<StorageAccountKey2>' with the keys of the storage account.

    ```diff
    "virtualMachineProfile": {
        "extensionProfile": {
            "extensions": [
                {
                    "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
                    "properties": {
                        "type": "ServiceFabricNode",
                        "autoUpgradeMinorVersion": true,
    +                    "protectedSettings": {
    +                        "StorageAccountKey1": "<StorageAccountKey1>",
    +                        "StorageAccountKey2": "<StorageAccountKey2>"
    +                    },
                        "publisher": "Microsoft.Azure.ServiceFabric",
    ...
    ```

1. At top of page, click PUT.

    ![Click PUT](../media/resourcemgr7.png)

1. **Wait** for the virtual machine scale set 'Updating' 'provisioningState' for the storage keys to complete. At the top of page, click GET to check status. Verify "provisioningState" shows "Succeeded". If "provisioningState" equals "Updating", continue to periodically click GET at top of page to requery scale set.

    ![GET](../media/resourcemgr2.png)

    ![resources.azure.com vmss provisioningstate succeeded](../media/resourcemgr11.png)

1. Repeat steps 1-4 for 'StorageAccountKey2'/'key2' of storage account.

## Troubleshooting

1. If the cluster is not in a healthy state after the storage account key rotation, check the status of cluster system service 'fabric:/System/EventStoreService' in Service Fabric Explorer.

    ![EventStoreService](../media/eventstoreservice.png)

    If the cluster is not in a healthy state, the cluster system service 'fabric:/System/EventStoreService' will be in an error state. The error message will indicate the storage account key that is not valid.

    ![EventStoreService Error](../media/eventstoreservice-error.png)

1. Check the cluster system service 'fabric:/System/EventStoreService' in Service Fabric Explorer for the following error message:

    ```text
    'FabricDCA' reported Error for property 'DataCollectionAgent.Blob_WindowsFabric_AzureBlobServiceFabricEtw_BlobInitializer'. 
    The Data Collection Agent (DCA) encountered an exception when trying to initialize Azure Storage. 
    Diagnostics information will be left uncollected if this continues to happen.. 
    Failed trying to access storage account. Please verify if the connection string provided is correct. 
    AccountName: sflogsstorageaccount ContainerName : fabriclogs-a1be7d22-6f5d-4c0b-aca8-d9be5dfde24c. The remote server returned an error: (403) Forbidden.
    ```

    ```text
    'System.FM' reported Error for property 'State'.
    Partition is in quorum loss. As the replicas come up, partition should recover from the quorum loss. Service Fabric will force recover partition from the quorum loss after <a href="https://docs.microsoft.com/en-us/dotnet/api/system.fabric.description.statefulservicedescription.quorumlosswaitduration?view=azure-dotnet ">QuorumLossWaitDuration</a> (TimeSpan: infinite) expires.
    If the partition has been in this state for more than expected time then please refer to the <a href="https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-disaster-recovery#random-failures-leading-to-service-failures ">troubleshooting guide</a>.

    EventStoreService 3 3 00000000-0000-0000-0000-000000009000
    N/S Down _nt0_0 133456514055978671
    N/S Ready _nt0_2 133456514280436309
    N/P Down _nt0_1 133456514280436310
    ```

1. Check the Application Event Log on the cluster nodes for errors or exceptions for 'EventStore.Service.exe' indicating a configuration issue with the storage account key.:

    ```text
    Log Name:      Application
    Source:        Windows Error Reporting
    Date:          12/4/2023 2:01:54 PM
    Event ID:      1001
    Task Category: None
    Level:         Information
    Keywords:      Classic
    User:          N/A
    Computer:      nt0000000
    Description:
    Fault bucket 1491601584461759603, type 5
    Event Name: CLR20r3
    Response: Not available
    Cab Id: 0

    Problem signature:
    P1: EventStore.Service.exe
    P2: 10.0.1949.9590
    P3: 652ec981
    P4: System
    P5: 4.8.4682.0
    P6: 6541ba61
    P7: a24
    P8: 20
    P9: System.Net.WebException
    P10: 
    ```

    ![Event ID 1004](../media/eventid1004.png)