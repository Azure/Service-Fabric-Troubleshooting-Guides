# BackupRestoreService(BRS) stops taking periodic backup after upgrade to latest runtime

## Applies to

Clusters upgraded to 8.2.1235.9590 / 9.0.1107.9590 / 9.1.1387.9590 which have existing backup policies enabled on any stateful partition/service/app.

## Symptoms

- For clusters that are upgraded to versions 8.2.1235.9590 / 9.0.1107.9590 / 9.1.1387.9590 with existing backup policies, BRS stops taking backup and restores on the services in question 
- When triggering a new backup and restore operation, the restore will fail 
- On the logs we see errors like: 

  ```
   2f2f40a4-b8a6-416b-98c2-939ea60b0d77 Error encountered in BackupRestoreWorker InitializeAsync System.Runtime.Serialization.SerializationException: Error in line 1 position 198. 'Element' '_x003C_NumberOfBackupsInChain_x003E_k__BackingField' from namespace 'http://schemas.datacontract.org/2004/07/System.Fabric.BackupRestore' is not expected. Expecting element '_x003C_NextBackupTime_x003E_k__BackingField'.
    at System.Runtime.Serialization.XmlObjectSerializerReadContext.ThrowRequiredMemberMissingException(XmlReaderDelegator xmlReader, Int32 memberIndex, Int32 requiredIndex, XmlDictionaryString[] memberNames)
    at System.Runtime.Serialization.XmlObjectSerializerReadContext.GetMemberIndexWithRequiredMembers(XmlReaderDelegator xmlReader, XmlDictionaryString[] memberNames, XmlDictionaryString[] memberNamespaces, Int32 memberIndex, Int32 requiredIndex, ExtensionDataObject extensionData)
    at ReadBackupMetadataFromXml(XmlReaderDelegator , XmlObjectSerializerReadContext , XmlDictionaryString[] , XmlDictionaryString[] )
    at System.Runtime.Serialization.ClassDataContract.ReadXmlValue(XmlReaderDelegator xmlReader, XmlObjectSerializerReadContext context)
    at System.Runtime.Serialization.XmlObjectSerializerReadContext.InternalDeserialize(XmlReaderDelegator reader, String name, String ns, Type declaredType, DataContract& dataContract)
    at System.Runtime.Serialization.XmlObjectSerializerReadContext.InternalDeserialize(XmlReaderDelegator xmlReader, Type declaredType, DataContract dataContract, String name, String ns)
    at System.Runtime.Serialization.DataContractSerializer.InternalReadObject(XmlReaderDelegator xmlReader, Boolean verifyObjectName, DataContractResolver dataContractResolver)
    at System.Runtime.Serialization.XmlObjectSerializer.ReadObjectHandleExceptions(XmlReaderDelegator reader, Boolean verifyObjectName, DataContractResolver dataContractResolver)
    at System.Fabric.BackupRestore.BackupMetadata.Deserialize(Byte[] serializedBytes)
    at System.Fabric.BackupRestore.BackupRestoreManager.InitializeAsync(CancellationToken cancellationToken)
    ```

## Cause 

- On new release there was a change on the schema on BRS adding the new NextBackupTime parameter 


## Mitigation

To mitigate, we need to update the existing policy after upgrading to runtime 8.2.1235.9590 / 9.0.1107.9590 / 9.1.1387.9590. User can call updatebackuppolicy API as mentioned in this doc <https://learn.microsoft.com/en-us/rest/api/servicefabric/sfclient-api-updatebackuppolicy> with existing policy values. It will update the policy model inside BRS with new data model and BRS will start taking periodic backups again.

## Steps

1. Check if there were some existing backup policies applied on any application/service/partition before upgrading to 8.2.1235.9590 / 9.0.1107.9590 / 9.1.1387.9590
2. Check if periodic backups are stopped post upgrading and above error is appearing in logs. above errors are appearing
3. Update the backup policy with same old values by calling updatebackuppolicy API. Below is one sample 



   ```
        $BackupPolicy=@{  
        Name = "DailyAzureBackupPolicy" 
        AutoRestoreOnDataLoss = "false" 
        MaxIncrementalBackups = "3" 
        Schedule = @{ 
            ScheduleKind = "FrequencyBased" 
            Interval = "PT3M" 
          } 
        Storage = @{ 
            StorageKind = "AzureBlobStore" 
            FriendlyName = "Azure_storagesample" 
            ConnectionString = "<connection string values>" 
            ContainerName = "<Container Name>" 
          } 
        RetentionPolicy = @{ 
            RetentionPolicyType = "Basic" 
            MinimumNumberOfBackups = "20" 
            RetentionDuration = "P3M" 
          } 
        } 
        $body = (ConvertTo-Json $BackupPolicy) 
        $url = 'https://<ClusterEndPoint>:19080/BackupRestore/BackupPolicies/DailyAzureBackupPolicy/$/Update?api-version=6.4' 
        Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType 'application/json' -CertificateThumbprint '<Thumbprint>' 
        #User should update the name of backup policy [DailyAzureBackupPolicy being used here and other possible values accordinly].
    
    ```

4. Wait for 1-2 mins and policy should get updated across all entities.

5. Periodic backups will start happening as per backup policy.




