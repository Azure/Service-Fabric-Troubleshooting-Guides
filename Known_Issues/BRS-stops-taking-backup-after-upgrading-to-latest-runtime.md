# BackupRestoreService(BRS) stops taking periodic backup after upgrade to latest runtime

**Issue**: Periodic backups stop for configured backup policies

**Cluster versions impacted:** Clusters upgraded to 8.2.1686.9590 / 9.0.1107.9590 / 9.1.1387.9590 which have existing backup policies enabled on any stateful partition/service/app.

**Impact**: If SF cluster is upgraded to 8.2.1686.9590 / 9.0.1107.9590 / 9.1.1387.9590 which has existing backup policies, post upgrade BRS fails deserialize old metadata with changes in new release. It will stop taking backup and restore on the partition/service/app in question, though cluster and BRS remains healthy.

**Identifying the issue:**

There are two ways to identifying and confirming the issue

1. If periodic backups were happening on any partition, it should be visible on SFX under Cluster->Application->Service->Partition->Backup. Here list of all backups being taken with creation time is available. Using this info and upgrade time, customer can identify wether backup policy was enabled, backups were happening before upgrade and whether backups are happening post upgrade.

2. Another way of checking and enumerating backups is calling this API [Get partition backup list](https://learn.microsoft.com/en-us/rest/api/servicefabric/sfclient-api-getpartitionbackuplist).


**Mitigation:**

To mitigate, we need to update the existing policy after upgrading to runtime 8.2.1686.9590 / 9.0.1107.9590 / 9.1.1387.9590. User can call [UpdateBackupPolicy](https://learn.microsoft.com/en-us/rest/api/servicefabric/sfclient-api-updatebackuppolicy) with existing policy values. It will update the policy model inside BRS with new data model and BRS will start taking periodic backups again.

**Steps**:

1. Check if there were some existing backup policies applied on any application/service/partition before upgrading to 8.2.1686.9590 / 9.0.1107.9590 / 9.1.1387.9590
2. Check if periodic backups are stopped post upgrading and above error is appearing in logs.
above errors are appearing
3. Update the backup policy with same old values by calling UpdateBackupPolicy API. Below is one sample -

    ```powershell
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
      # User should update the name of backup policy [DailyAzureBackupPolicy being used here and other possible values accordingly].
    ```

4. Wait for 1-2 mins and policy should get updated across all entities.
5. Periodic backups will start happening as per backup policy.
