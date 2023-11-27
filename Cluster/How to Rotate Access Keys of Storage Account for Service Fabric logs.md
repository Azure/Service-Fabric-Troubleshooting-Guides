# How to Rotate Access Keys of Storage Account for Service Fabric logs

This troubleshooting guide describes the steps to rotate Storage Account Keys for the storage account used for Service Fabric Logs. This guide is applicable for Service Fabric clusters only. Service Fabric Managed clusters do not use storage account keys for Service Fabric logs.

Best practice is to provision and manage Service Fabric clusters using ARM templates. This guide describes the steps to rotate Storage Account Keys using ARM templates. If you are not using ARM templates to provision and manage Service Fabric clusters, you can use [resources.azure.com](https://resources.azure.com) to modify the Service Fabric resource to rotate Storage Account Keys.

## Modify using ARM Template

1. Verify current Virtual Machine Scale Set (VMSS) Service Fabric extension storage configuration.
    * In the Service Fabric VM Extension section, verify there are two storage keys configured and 'StorageAccountKey2' refers to key2 of storage account. If you have configured only one key 'StorageAccountKey1', add a second key 'StorageAccountKey2'.

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

        ![Storage Account Keys](../media/storage-account-access-keys.png)

1. Verify current Storage Account Key configuration for Service Fabric resource is using 'StorageAccountKey2'.

    This can be verified by looking at 'protectedAccountKeyName' in 'diagnosticsStorageAccountConfig' section under Service Fabric resource of the ARM template. If not correct, modify 'protectedAccountKeyName' and set to 'StorageAccountKey2'.

    * Set the value of 'protectedAccountKeyName' to 'StorageAccountKey2' in 'diagnosticsStorageAccountConfig' section of the Service Fabric resource, while keeping the rest unchanged.

        ```diff
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
        -                "protectedAccountKeyName": "StorageAccountKey1", 
        +                "protectedAccountKeyName": "StorageAccountKey2", 
                    "queueEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.queue]",
                    "storageAccountName": "[parameters('supportLogStorageAccountName')]",
                    "tableEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.table]"
                },
        ...
        ```

1. Rotate Storage Account Key.

    Rotate 'StorageAccountKey1'/'key1' of storage account using by clicking 'Rotate key' in the storage account 'Access Keys'. See [Manually Rotate Access Keys](https://learn.microsoft.com/azure/storage/common/storage-account-keys-manage?tabs=azure-portal#manually-rotate-access-keys") for detailed steps.

1. After rotation, update Service Fabric resource to point to  new 'StorageAccountKey1'.

    Use 'StorageAccountKey1' of storage account in 'diagnosticsStorageAccountConfig' section of  Service Fabric resource using ARM template deployment as following.

    * In the Service Fabric VM Extension section, make sure you have configured two storage keys and 'StorageAccountKey1' refers to StorageAccountKey1 of storage account.

    ```diff
        "protectedSettings": {
    -    "StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key1]",
    +    "StorageAccountKey1": "<(new) StorageAccountKey1>",
        "StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key2]"
    },
    ```

    * Set the value of 'protectedAccountKeyName' to 'StorageAccountKey1' in 'diagnosticsStorageAccountConfig' section of the Service Fabric resource, while keeping the rest unchanged.

    ```diff
    "diagnosticsStorageAccountConfig": {
        "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.blob]",
    -       "protectedAccountKeyName": "StorageAccountKey2", 
    +       "protectedAccountKeyName": "StorageAccountKey1", 
    ```

1. Deploy the ARM template to update the Service Fabric resource.

1. Repeat steps 1-4 for 'StorageAccountKey2'/'key2' of storage account.

    * In the Service Fabric VM Extension section, make sure you have configured two storage keys and 'StorageAccountKey2' refers to StorageAccountKey2 of storage account.

    ```diff
        "protectedSettings": {
        "StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key1]",
    -    "StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key2]"
    +    "StorageAccountKey2": "<(new) StorageAccountKey2>"
    },
    ```

    * Set the value of 'protectedAccountKeyName' to 'StorageAccountKey2' in 'diagnosticsStorageAccountConfig' section of the Service Fabric resource, while keeping the rest unchanged.

    ```diff
    "diagnosticsStorageAccountConfig": {
        "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters('supportLogStorageAccountName')), variables('storageApiVersion')).primaryEndpoints.blob]",
    -       "protectedAccountKeyName": "StorageAccountKey1", 
    +       "protectedAccountKeyName": "StorageAccountKey2", 
    ```

1. Deploy the ARM template to update the Service Fabric resource.

1. Verify successful configuration by reviewing cluster state in Service Fabric Explorer. The cluster nodes should not have any warnings or errors related to the storage account.

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