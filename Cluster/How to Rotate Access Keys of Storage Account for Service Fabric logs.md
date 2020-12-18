# How to Rotate Access Keys of Storage Account for Service Fabric logs

This troubleshooting guide describes the steps of rotating StorageAccountKey1 of storage account used for Service Fabric Logs. StorageAccountKey2 can be rotated in similar fashion.

Rotating StorageAccountKey1 requires three steps.

## Step 1

First step is to make sure you are using StorageAccountKey2 of storage account in ‘diagnosticsStorageAccountConfig’ section of Service Fabric resource. 

This can be verified by looking at 'protectedAccountKeyName' in ‘diagnosticsStorageAccountConfig’ section under Service Fabric resource of the ARM template. Make sure that 'protectedAccountKeyName' is pointing at StorageAccountKey2 of storage account. 


If 'protectedAccountKeyName' is pointing at StorageAccountKey1 then you can use ARM template deployment to point it to StorageAccountKey2 as following. 

* In the Service Fabric VM Extension section, make sure you have configured two storage keys and 'StorageAccountKey2' refers to StorageAccountKey2 of storage account. If you have configured only one key ‘StorageAccountKey1’, add a second key ‘StorageAccountKey2’.
<pre><code>"StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(StorageAccount)),'2015-05-01-preview').key1]",

<b>"StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(StorageAccount)),'2015-05-01-preview').key2]"
</b>
</code></pre>

* Set the value of ‘protectedAccountKeyName’ to ‘StorageAccountKey2’ in ‘diagnosticsStorageAccountConfig’ section of the Service Fabric resource, while keeping the rest unchanged.

<pre><code>"diagnosticsStorageAccountConfig": {
     
    "protectedAccountKeyName": "StorageAccountKey2"
		
    …
}
</code></pre>


## Step 2

<a href="https://docs.microsoft.com/en-us/azure/storage/common/storage-account-keys-manage?tabs=azure-portal#manually-rotate-access-keys">Rotate StorageAccountKey1 of storage account. </a>

## Step 3

Use StorageAccountKey1 of storage account in ‘diagnosticsStorageAccountConfig’ section of  Service Fabric resource using ARM template deployment as following.

* In the Service Fabric VM Extension section, make sure you have configured two storage keys and 'StorageAccountKey1' refers to StorageAccountKey1 of storage account. 
<pre><code><b>"StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(StorageAccount)),'2015-05-01-preview').key1]",</b>

"StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(StorageAccount)),'2015-05-01-preview').key2]"
</code></pre>

* Set the value of ‘protectedAccountKeyName’ to ‘StorageAccountKey1’ in ‘diagnosticsStorageAccountConfig’ section of the Service Fabric resource, while keeping the rest unchanged.

<pre><code>"diagnosticsStorageAccountConfig": {
     
    "protectedAccountKeyName": "StorageAccountKey1"
		
    …
}
</code></pre>