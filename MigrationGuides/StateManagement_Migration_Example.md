# State Management Migration Example: Azure Cloud Services to Service Fabric

> **Important Disclaimer**: This document demonstrates how to migrate state management to Service Fabric's Reliable Collections, but it's important to note that this is not a requirement. You can continue using external state stores (like Azure Table Storage, Azure SQL Database, etc.) with your Service Fabric services. The migration to Reliable Collections is an option that you may consider if you want to take advantage of the benefits of stateful services, such as:
> - Lower latency for stateful operations
> - Built-in replication and high availability
> - Transactional consistency
> - Simplified state management within the cluster
>
> However, if your current external state store is working well for your needs, you can keep using it with Service Fabric services. The services can still access external stores while running in Service Fabric.

This document provides a detailed technical guide for migrating application state management from external storage solutions to Service Fabric's native state management capabilities. It covers the transition to Reliable Collections with practical implementation patterns, data migration strategies, and state persistence techniques. You'll find concrete code examples for common scenarios like session state management, workflow processing, and caching implementations, along with guidance on backup, restore, and disaster recovery procedures. The examples demonstrate both complete migration to Reliable Collections and hybrid approaches that combine Service Fabric state management with external data stores.

## Table of Contents
1. [Overview](#overview)
2. [Reliable Collections Introduction](#reliable-collections-introduction)
3. [Migration Strategies](#migration-strategies)
4. [Implementation Examples](#implementation-examples)
5. [Data Migration](#data-migration)
6. [State Backup and Restore](#state-backup-and-restore)

## Overview

Service Fabric provides several options for state management:
- Reliable Collections (in-memory, replicated state)
- Reliable Actors (actor model for distributed state)
- External State Stores (Azure SQL, Cosmos DB, etc.)

## Reliable Collections Introduction

### Available Collections
```csharp
// Dictionary for key-value pairs
IReliableDictionary<TKey, TValue>

// Queue for FIFO operations
IReliableQueue<T>

// Concurrent Queue for concurrent operations
IReliableConcurrentQueue<T>

// State Manager for collection management
IReliableStateManager
```

### Basic Usage
```csharp
public class StatefulService : StatefulService
{
    private IReliableDictionary<string, string> _dictionary;
    private IReliableQueue<string> _queue;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Initialize collections
        _dictionary = await StateManager.GetOrAddAsync<IReliableDictionary<string, string>>("MyDictionary");
        _queue = await StateManager.GetOrAddAsync<IReliableQueue<string>>("MyQueue");

        while (!cancellationToken.IsCancellationRequested)
        {
            // Use collections within transactions
            using (var tx = StateManager.CreateTransaction())
            {
                await _dictionary.AddOrUpdateAsync(tx, "key", "value", (k, v) => "newValue");
                await _queue.EnqueueAsync(tx, "item");
                await tx.CommitAsync();
            }
        }
    }
}
```

## Migration Strategies

### 1. Direct Migration to Reliable Collections
```csharp
public class StateMigrationService
{
    private readonly IReliableStateManager _stateManager;
    private readonly CloudTable _azureTable;

    public async Task MigrateTableToDictionaryAsync(CancellationToken cancellationToken)
    {
        var dictionary = await _stateManager.GetOrAddAsync<IReliableDictionary<string, Entity>>("Entities");

        using (var tx = _stateManager.CreateTransaction())
        {
            // Query Azure Table
            var entities = await _azureTable.ExecuteQuerySegmentedAsync(
                new TableQuery<Entity>(),
                null,
                cancellationToken);

            // Migrate to Reliable Dictionary
            foreach (var entity in entities)
            {
                await dictionary.AddOrUpdateAsync(
                    tx,
                    entity.RowKey,
                    entity,
                    (key, oldValue) => entity);
            }

            await tx.CommitAsync();
        }
    }
}
```

### 2. Hybrid Approach with External Store
```csharp
public class HybridStateService : StatefulService
{
    private readonly IReliableDictionary<string, CacheEntry> _cache;
    private readonly CloudTable _azureTable;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        _cache = await StateManager.GetOrAddAsync<IReliableDictionary<string, CacheEntry>>("Cache");

        while (!cancellationToken.IsCancellationRequested)
        {
            // Use cache for hot data
            using (var tx = StateManager.CreateTransaction())
            {
                var entry = await _cache.TryGetValueAsync(tx, "key");
                if (!entry.HasValue)
                {
                    // Fall back to Azure Table
                    var entity = await _azureTable.ExecuteAsync(
                        TableOperation.Retrieve<Entity>("partition", "row"),
                        cancellationToken);

                    await _cache.AddAsync(tx, "key", new CacheEntry(entity));
                }
                await tx.CommitAsync();
            }
        }
    }
}
```

## Implementation Examples

### 1. User Session State
```csharp
public class UserSessionService : StatefulService
{
    private IReliableDictionary<string, UserSession> _sessions;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        _sessions = await StateManager.GetOrAddAsync<IReliableDictionary<string, UserSession>>("Sessions");

        while (!cancellationToken.IsCancellationRequested)
        {
            // Handle session operations
            using (var tx = StateManager.CreateTransaction())
            {
                // Update session
                await _sessions.AddOrUpdateAsync(
                    tx,
                    "userId",
                    new UserSession { LastAccess = DateTime.UtcNow },
                    (key, oldValue) =>
                    {
                        oldValue.LastAccess = DateTime.UtcNow;
                        return oldValue;
                    });

                await tx.CommitAsync();
            }
        }
    }
}
```

### 2. Workflow State
```csharp
public class WorkflowStateService : StatefulService
{
    private IReliableDictionary<string, WorkflowState> _workflows;
    private IReliableQueue<WorkflowEvent> _events;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        _workflows = await StateManager.GetOrAddAsync<IReliableDictionary<string, WorkflowState>>("Workflows");
        _events = await StateManager.GetOrAddAsync<IReliableQueue<WorkflowEvent>>("Events");

        while (!cancellationToken.IsCancellationRequested)
        {
            using (var tx = StateManager.CreateTransaction())
            {
                // Process workflow events
                var eventResult = await _events.TryDequeueAsync(tx);
                if (eventResult.HasValue)
                {
                    var workflow = await _workflows.GetOrAddAsync(
                        tx,
                        eventResult.Value.WorkflowId,
                        new WorkflowState());

                    workflow.ApplyEvent(eventResult.Value);
                    await _workflows.SetAsync(tx, eventResult.Value.WorkflowId, workflow);
                }

                await tx.CommitAsync();
            }
        }
    }
}
```

## Data Migration

### 1. Bulk Data Migration
```csharp
public class BulkMigrationService
{
    private readonly IReliableStateManager _stateManager;
    private readonly CloudTable _sourceTable;

    public async Task MigrateBulkDataAsync(CancellationToken cancellationToken)
    {
        var dictionary = await _stateManager.GetOrAddAsync<IReliableDictionary<string, Entity>>("Entities");

        // Process in batches
        TableContinuationToken token = null;
        do
        {
            var segment = await _sourceTable.ExecuteQuerySegmentedAsync(
                new TableQuery<Entity>(),
                token,
                cancellationToken);

            using (var tx = _stateManager.CreateTransaction())
            {
                foreach (var entity in segment)
                {
                    await dictionary.AddOrUpdateAsync(
                        tx,
                        entity.RowKey,
                        entity,
                        (key, oldValue) => entity);
                }
                await tx.CommitAsync();
            }

            token = segment.ContinuationToken;
        } while (token != null);
    }
}
```

### 2. Incremental Migration
```csharp
public class IncrementalMigrationService
{
    private readonly IReliableDictionary<string, MigrationStatus> _migrationStatus;
    private readonly CloudTable _sourceTable;

    public async Task MigrateIncrementallyAsync(CancellationToken cancellationToken)
    {
        var dictionary = await _stateManager.GetOrAddAsync<IReliableDictionary<string, Entity>>("Entities");
        _migrationStatus = await _stateManager.GetOrAddAsync<IReliableDictionary<string, MigrationStatus>>("MigrationStatus");

        using (var tx = _stateManager.CreateTransaction())
        {
            var status = await _migrationStatus.GetOrAddAsync(tx, "Status", new MigrationStatus());
            
            // Migrate next batch
            var segment = await _sourceTable.ExecuteQuerySegmentedAsync(
                new TableQuery<Entity>().Where(
                    TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.GreaterThan, status.LastProcessedKey)),
                null,
                cancellationToken);

            foreach (var entity in segment)
            {
                await dictionary.AddOrUpdateAsync(
                    tx,
                    entity.RowKey,
                    entity,
                    (key, oldValue) => entity);

                status.LastProcessedKey = entity.PartitionKey;
            }

            await _migrationStatus.SetAsync(tx, "Status", status);
            await tx.CommitAsync();
        }
    }
}
```

## State Backup and Restore

Service Fabric provides a built-in [Periodic Backup and Restore](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-configure-periodic-backup) feature that can be configured at the application, service, or partition level. This is the recommended approach for backing up stateful services.

### 1. Backup Policy Configuration

First, create a backup policy that defines:
- Backup schedule (frequency-based or time-based)
- Storage location (Azure Blob Store or File Share)
- Retention policy
- Auto-restore settings

#### Using Managed Identity for Azure Blob Storage

1. First, enable managed identity on your Service Fabric cluster's VMSS:

```powershell
# Enable system-assigned managed identity
$vmss = Get-AzVmss -ResourceGroupName "MyResourceGroup" -VMScaleSetName "MyClusterVMSS"
Update-AzVmss -ResourceGroupName "MyResourceGroup" -Name "MyClusterVMSS" -VirtualMachineScaleSet $vmss -IdentityType "SystemAssigned"

# Or enable user-assigned managed identity
$identity = New-AzUserAssignedIdentity -ResourceGroupName "MyResourceGroup" -Name "MyBackupIdentity"
$vmss = Get-AzVmss -ResourceGroupName "MyResourceGroup" -VMScaleSetName "MyClusterVMSS"
Update-AzVmss -ResourceGroupName "MyResourceGroup" -Name "MyClusterVMSS" -VirtualMachineScaleSet $vmss -IdentityType "UserAssigned" -IdentityId $identity.Id
```

2. Assign the necessary RBAC roles:

```powershell
# Get the managed identity principal ID
$principalId = (Get-AzUserAssignedIdentity -ResourceGroupName "MyResourceGroup" -Name "MyBackupIdentity").PrincipalId

# Assign Storage Blob Data Contributor role
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account>"
```

3. Configure backup policy with managed identity:

```json
{
    "Name": "DailyBackupPolicy",
    "AutoRestoreOnDataLoss": false,
    "MaxIncrementalBackups": 20,
    "Schedule": {
        "ScheduleKind": "TimeBased",
        "ScheduleFrequencyType": "Daily",
        "RunTimes": [
            "0001-01-01T09:00:00Z",
            "0001-01-01T18:00:00Z"
        ]
    },
    "Storage": {
        "StorageKind": "ManagedIdentityAzureBlobStore",
        "FriendlyName": "AzureMI_storagesample",
        "BlobServiceUri": "https://<account-name>.blob.core.windows.net",
        "ContainerName": "backup-container",
        "ManagedIdentityType": "VMSS",
        "ManagedIdentityClientId": "<Client-Id of User-Assigned MI>"  // Optional, only needed if using user-assigned identity
    },
    "RetentionPolicy": {
        "RetentionPolicyType": "Basic",
        "RetentionDuration": "P7D",
        "MinimumNumberOfBackups": 5
    }
}
```

### 2. Enable Backup for Application

Use the Service Fabric Backup Restore Service API to enable backup for your application:

```powershell
# Create backup policy
$policy = @{
    Name = "DailyBackupPolicy"
    AutoRestoreOnDataLoss = $false
    MaxIncrementalBackups = 20
    Schedule = @{
        ScheduleKind = "TimeBased"
        ScheduleFrequencyType = "Daily"
        RunTimes = @("09:00", "18:00")
    }
    Storage = @{
        StorageKind = "ManagedIdentityAzureBlobStore"
        FriendlyName = "AzureMI_storagesample"
        BlobServiceUri = "https://<account-name>.blob.core.windows.net"
        ContainerName = "backup-container"
        ManagedIdentityType = "VMSS"
    }
    RetentionPolicy = @{
        RetentionPolicyType = "Basic"
        RetentionDuration = "P7D"
        MinimumNumberOfBackups = 5
    }
}

# Enable backup using Service Fabric REST API
$body = @{
    BackupPolicy = $policy
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/EnableBackup" -Method Post -Body $body -ContentType "application/json"
```

### 3. Monitor Backup Status

Monitor the backup status using the Service Fabric REST API:

```powershell
# Get backup configuration
$config = Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/GetBackupConfigurationInfo" -Method Get

# Get backup list
$backups = Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/GetBackupList" -Method Get

# Get backup storage info
$storageInfo = Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/GetBackupStorageInfo" -Method Get
```

### 4. Restore from Backup

Restore from a backup using the Service Fabric REST API:

```powershell
# Get latest backup
$backups = Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/GetBackupList" -Method Get
$latestBackup = $backups | Sort-Object BackupTime -Descending | Select-Object -First 1

# Start restore
$body = @{
    BackupId = $latestBackup.BackupId
    Force = $true
} | ConvertTo-Json

$restoreOperation = Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/StartRestore" -Method Post -Body $body -ContentType "application/json"

# Wait for restore completion
$operationId = $restoreOperation.OperationId
$status = Invoke-RestMethod -Uri "http://localhost:19080/Applications/$applicationId/$/GetRestoreProgress?OperationId=$operationId" -Method Get
```

### Important Considerations

1. **Backup Storage**:
   - For Azure clusters, use Azure Blob Storage with managed identity when possible
   - For standalone clusters, use file share storage
   - Ensure storage reliability meets your requirements

2. **Backup Schedule**:
   - Choose appropriate backup frequency based on data change rate
   - Consider using incremental backups to optimize storage usage
   - Schedule backups during low-traffic periods

3. **Retention Policy**:
   - Set appropriate retention duration based on compliance requirements
   - Consider minimum number of backups needed for recovery
   - Monitor storage costs

4. **Auto Restore**:
   - Disable auto-restore in production clusters
   - Implement manual restore procedures
   - Test restore procedures regularly

5. **Monitoring**:
   - Monitor backup success/failure rates
   - Set up alerts for backup failures
   - Track storage usage

### Additional Resources

- [Service Fabric Backup and Restore Service](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-quickstart-azurecluster)
- [Configure Periodic Backup](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-configure-periodic-backup)
- [Backup and Restore Service REST API Reference](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-backup-restore-service-rest-api-reference)
- [Service Fabric Backup and Restore Service Overview](https://learn.microsoft.com/en-us/rest/api/servicefabric/sfclient-index-backuprestore)
