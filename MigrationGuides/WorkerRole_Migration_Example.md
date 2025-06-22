# Worker Role Migration Example: Azure Cloud Services to Service Fabric

This document provides a comprehensive step-by-step guide for migrating a Worker Role from Azure Cloud Services to a Service Fabric Stateless Service. It demonstrates the architectural transition from traditional background processing in Cloud Services to the reliable task execution patterns in Service Fabric. The guide includes side-by-side code comparisons showing how to implement reliable timers, queue processing, state persistence, and health monitoring. Each section contains practical implementation examples to help you successfully transform your background processing workloads to leverage Service Fabric's resilience features and distributed architecture.

## Table of Contents
1. [Project Structure Migration](#project-structure-migration)
2. [Service Implementation](#service-implementation)
3. [Background Processing](#background-processing)
4. [Queue Processing](#queue-processing)
5. [State Management](#state-management)
6. [Health Monitoring](#health-monitoring)
7. [Deployment Configuration](#deployment-configuration)
8. [Key Migration Considerations](#key-migration-considerations)

## Project Structure Migration

First, create the new Service Fabric application and service:

```powershell
# Create new Service Fabric Application
New-ServiceFabricApplication -ApplicationName "fabric:/MyWorkerApp" -ApplicationTypeName "MyWorkerAppType" -ApplicationTypeVersion "1.0.0"

# Create new Stateless Service
New-ServiceFabricService -ApplicationName "fabric:/MyWorkerApp" -ServiceName "fabric:/MyWorkerApp/WorkerService" -ServiceTypeName "WorkerServiceType" -Stateless -PartitionSchemeSingleton -InstanceCount 1
```

## Service Implementation

### Original Worker Role
```csharp
public class WorkerRole : RoleEntryPoint
{
    public override void Run()
    {
        // Worker Role processing code
        while (true)
        {
            // Process items from queue
            ProcessQueueItems();
            Thread.Sleep(TimeSpan.FromSeconds(30));
        }
    }
}
```

### New Service Fabric Stateless Service
```csharp
public class WorkerService : StatelessService
{
    private readonly ILogger<WorkerService> _logger;
    private readonly IConfiguration _configuration;
    private readonly IReliableQueue<WorkItem> _workQueue;
    private readonly IReliableStateManager _stateManager;

    public WorkerService(
        StatelessServiceContext context,
        ILogger<WorkerService> logger,
        IConfiguration configuration)
        : base(context)
    {
        _logger = logger;
        _configuration = configuration;
        _stateManager = context.StateManager;
    }

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Initialize reliable collections
        _workQueue = await _stateManager.GetOrAddAsync<IReliableQueue<WorkItem>>("WorkQueue");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await ProcessWorkItemsAsync(cancellationToken);
                await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing work items");
            }
        }
    }

    private async Task ProcessWorkItemsAsync(CancellationToken cancellationToken)
    {
        using (var tx = _stateManager.CreateTransaction())
        {
            var workItem = await _workQueue.TryDequeueAsync(tx);
            if (workItem.HasValue)
            {
                await ProcessWorkItemAsync(workItem.Value, cancellationToken);
                await tx.CommitAsync();
            }
        }
    }
}
```

## Background Processing

### Reliable Timer Implementation
```csharp
public class WorkerService : StatelessService
{
    private readonly IReliableTimer _timer;

    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        // Create reliable timer
        _timer = new ReliableTimer(
            async (cancellationToken) =>
            {
                await ProcessScheduledWorkAsync(cancellationToken);
            },
            TimeSpan.FromMinutes(5),
            cancellationToken);

        while (!cancellationToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
        }
    }

    private async Task ProcessScheduledWorkAsync(CancellationToken cancellationToken)
    {
        // Process scheduled work
        await DoScheduledWorkAsync(cancellationToken);
    }
}
```

### Background Job Processing
```csharp
public class BackgroundJobProcessor
{
    private readonly IReliableDictionary<string, JobStatus> _jobStatus;
    private readonly IReliableQueue<Job> _jobQueue;

    public async Task ProcessJobAsync(Job job, CancellationToken cancellationToken)
    {
        using (var tx = _stateManager.CreateTransaction())
        {
            // Update job status
            await _jobStatus.AddOrUpdateAsync(
                tx,
                job.Id,
                JobStatus.InProgress,
                (key, oldValue) => JobStatus.InProgress);

            // Process job
            await ProcessJobLogicAsync(job, cancellationToken);

            // Update final status
            await _jobStatus.AddOrUpdateAsync(
                tx,
                job.Id,
                JobStatus.Completed,
                (key, oldValue) => JobStatus.Completed);

            await tx.CommitAsync();
        }
    }
}
```

## Queue Processing

### Azure Queue to Reliable Queue Migration
```csharp
public class QueueMigrationService
{
    private readonly CloudQueue _azureQueue;
    private readonly IReliableQueue<WorkItem> _reliableQueue;

    public async Task MigrateQueueItemsAsync(CancellationToken cancellationToken)
    {
        using (var tx = _stateManager.CreateTransaction())
        {
            var messages = await _azureQueue.GetMessagesAsync(32);
            foreach (var message in messages)
            {
                var workItem = new WorkItem
                {
                    Id = message.Id,
                    Content = message.AsString,
                    DequeueCount = message.DequeueCount
                };

                await _reliableQueue.EnqueueAsync(tx, workItem);
            }

            await tx.CommitAsync();
        }
    }
}
```

### Reliable Queue Processing
```csharp
public class QueueProcessor
{
    private readonly IReliableQueue<WorkItem> _queue;
    private readonly IReliableDictionary<string, ProcessingStatus> _status;

    public async Task ProcessQueueAsync(CancellationToken cancellationToken)
    {
        using (var tx = _stateManager.CreateTransaction())
        {
            var workItem = await _queue.TryDequeueAsync(tx);
            if (workItem.HasValue)
            {
                // Update processing status
                await _status.AddOrUpdateAsync(
                    tx,
                    workItem.Value.Id,
                    ProcessingStatus.InProgress,
                    (key, oldValue) => ProcessingStatus.InProgress);

                // Process work item
                await ProcessWorkItemAsync(workItem.Value, cancellationToken);

                // Update final status
                await _status.AddOrUpdateAsync(
                    tx,
                    workItem.Value.Id,
                    ProcessingStatus.Completed,
                    (key, oldValue) => ProcessingStatus.Completed);

                await tx.CommitAsync();
            }
        }
    }
}
```

## State Management

### Reliable Collections Usage
```csharp
public class WorkerStateManager
{
    private readonly IReliableStateManager _stateManager;
    private IReliableDictionary<string, WorkerState> _workerState;
    private IReliableQueue<WorkItem> _workQueue;

    public async Task InitializeAsync()
    {
        _workerState = await _stateManager.GetOrAddAsync<IReliableDictionary<string, WorkerState>>("WorkerState");
        _workQueue = await _stateManager.GetOrAddAsync<IReliableQueue<WorkItem>>("WorkQueue");
    }

    public async Task UpdateWorkerStateAsync(string workerId, WorkerState state)
    {
        using (var tx = _stateManager.CreateTransaction())
        {
            await _workerState.AddOrUpdateAsync(
                tx,
                workerId,
                state,
                (key, oldValue) => state);

            await tx.CommitAsync();
        }
    }
}
```

## Health Monitoring

```csharp
public class WorkerService : StatelessService
{
    protected override async Task RunAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            // Report health
            var healthInfo = new HealthInformation(
                "WorkerService",
                "ProcessingHealth",
                HealthState.Ok,
                $"Processed {_processedItems} items");

            Partition.ReportInstanceHealth(healthInfo);

            await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
        }
    }
}
```

## Deployment Configuration

```powershell
# Deploy the application
$publishProfile = "Local.1Node.xml"
$appPackagePath = "pkg\Debug"

Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $appPackagePath -ImageStoreConnectionString "file:C:\SfDevCluster\Data\ImageStoreShare" -ApplicationPackagePathInImageStore "MyWorkerApp"

Register-ServiceFabricApplicationType -ApplicationPathInImageStore "MyWorkerApp"

New-ServiceFabricApplication -ApplicationName "fabric:/MyWorkerApp" -ApplicationTypeName "MyWorkerAppType" -ApplicationTypeVersion "1.0.0"
```

## Key Migration Considerations

### 1. Queue Processing
- Migrate from Azure Queue to Reliable Queue
- Implement proper error handling
- Handle message visibility and retry logic
- Consider batch processing

### 2. State Management
- Use Reliable Collections for state
- Implement proper transaction handling
- Consider state partitioning
- Handle state backup and restore

### 3. Background Processing
- Implement reliable timers
- Handle cancellation properly
- Consider parallel processing
- Implement proper error handling

### 4. Monitoring and Diagnostics
- Implement health reporting
- Set up proper logging
- Configure performance counters
- Implement proper error tracking

## Additional Resources

- [Service Fabric Documentation](https://learn.microsoft.com/azure/service-fabric)
- [Reliable Collections](https://learn.microsoft.com/azure/service-fabric/service-fabric-reliable-services-reliable-collections)
- [Service Fabric Samples](https://github.com/Azure-Samples/service-fabric-dotnet-getting-started) 