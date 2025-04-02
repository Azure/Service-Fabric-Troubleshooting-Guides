# State Management Migration Example: Azure Cloud Services to Service Fabric

This document provides a comprehensive example of migrating state management from Azure Cloud Services to Service Fabric's Reliable Collections. It includes detailed code examples, configuration changes, and best practices for state management.

## Table of Contents
1. [Overview](#overview)
2. [Reliable Collections Introduction](#reliable-collections-introduction)
3. [Migration Strategies](#migration-strategies)
4. [Implementation Examples](#implementation-examples)
5. [Data Migration](#data-migration)
6. [State Backup and Restore](#state-backup-and-restore)
7. [Performance Optimization](#performance-optimization)
8. [Key Migration Considerations](#key-migration-considerations)

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

### 1. Backup Configuration
```xml
<ApplicationManifest ...>
  <ServiceManifestImport>
    <ServiceManifestRef ServiceManifestName="StatefulServicePkg" ServiceManifestVersion="1.0.0" />
    <ConfigOverrides>
      <ConfigOverride Name="Config">
        <Settings>
          <Section Name="BackupRestore">
            <Parameter Name="BackupInterval" Value="3600" />
            <Parameter Name="BackupRetentionPeriod" Value="86400" />
          </Section>
        </Settings>
      </ConfigOverride>
    </ConfigOverrides>
  </ServiceManifestImport>
</ApplicationManifest>
```

### 2. Backup Implementation
```csharp
public class BackupService : StatefulService
{
    private readonly TimeSpan _backupInterval;
    private readonly TimeSpan _retentionPeriod;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Create backup
                await BackupAsync(BackupOption.Full, cancellationToken);
                
                // Wait for next backup interval
                await Task.Delay(_backupInterval, cancellationToken);
            }
            catch (Exception ex)
            {
                // Handle backup errors
                ServiceEventSource.Current.ServiceMessage(
                    this.Context,
                    $"Backup failed: {ex.Message}");
            }
        }
    }

    private async Task BackupAsync(BackupOption option, CancellationToken cancellationToken)
    {
        var backupDescription = new BackupDescription(
            option,
            true, // Force backup
            this.BackupCallbackAsync);

        await this.BackupAsync(backupDescription, cancellationToken);
    }

    private async Task<bool> BackupCallbackAsync(BackupInfo backupInfo, CancellationToken cancellationToken)
    {
        // Implement backup callback
        return true;
    }
}
```

## Performance Optimization

### 1. Batch Operations
```csharp
public class BatchOperationService : StatefulService
{
    private IReliableDictionary<string, Entity> _dictionary;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        _dictionary = await StateManager.GetOrAddAsync<IReliableDictionary<string, Entity>>("Entities");

        while (!cancellationToken.IsCancellationRequested)
        {
            using (var tx = StateManager.CreateTransaction())
            {
                // Batch updates
                var tasks = new List<Task>();
                for (int i = 0; i < 100; i++)
                {
                    tasks.Add(_dictionary.AddOrUpdateAsync(
                        tx,
                        $"key{i}",
                        new Entity { Value = i },
                        (key, oldValue) => new Entity { Value = i }));
                }

                await Task.WhenAll(tasks);
                await tx.CommitAsync();
            }
        }
    }
}
```

### 2. Caching Strategy
```csharp
public class CachingService : StatefulService
{
    private IReliableDictionary<string, CacheEntry> _cache;
    private readonly TimeSpan _cacheTimeout;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        _cache = await StateManager.GetOrAddAsync<IReliableDictionary<string, CacheEntry>>("Cache");

        while (!cancellationToken.IsCancellationRequested)
        {
            using (var tx = StateManager.CreateTransaction())
            {
                var entry = await _cache.TryGetValueAsync(tx, "key");
                if (entry.HasValue && !entry.Value.IsExpired(_cacheTimeout))
                {
                    // Use cached value
                    ProcessValue(entry.Value);
                }
                else
                {
                    // Refresh cache
                    var newValue = await FetchValueAsync();
                    await _cache.SetAsync(tx, "key", new CacheEntry(newValue));
                }

                await tx.CommitAsync();
            }
        }
    }
}
```

## Key Migration Considerations

### 1. State Partitioning
- Choose appropriate partition scheme
- Consider data locality
- Handle partition rebalancing
- Implement partition-aware operations

### 2. Transaction Management
- Use transactions consistently
- Handle transaction timeouts
- Implement retry logic
- Consider transaction scope

### 3. Data Consistency
- Implement proper validation
- Handle concurrent updates
- Consider eventual consistency
- Implement conflict resolution

### 4. Performance
- Use batch operations
- Implement caching
- Optimize collection usage
- Monitor performance metrics

## Additional Resources

- [Service Fabric Documentation](https://docs.microsoft.com/azure/service-fabric)
- [Reliable Collections](https://docs.microsoft.com/azure/service-fabric/service-fabric-reliable-services-reliable-collections)
- [State Management](https://docs.microsoft.com/azure/service-fabric/service-fabric-reliable-services-state-management)
- [Service Fabric Samples](https://github.com/Azure-Samples/service-fabric-dotnet-getting-started) 