# Service Fabric 9.x, Cluster Repair Job Stuck EnsurePartitionQuorum

## Applies to

- Clusters on 9.x multiple versions

## Symptoms

- The Application in Warning is a Stateful application with Minimum and Target Replica Set values that are equal. Example Minimum 5 / Target 5.
- There is a partition in Warning with Kind EnsurePartitionQuorum.
- There is a long running RepairJob that is not progressing.
- The RepairJob is completing Health Checks.
- There is a Replica Role set to IdleSecondary.
- There are two or more service replicas in the same UpgradeDomain(UD).
- There may be an unhealthy node in the cluster.

## Possible Mitigations

Select one of the following Mitigation options to allow Repair job to resume progress:

### Option 1:

- Set the Application Service replica configuration Minimum Replica Set Size to a value that is less than Target Replica Set Size. Example: from 5/5 to 3/5

### Option 2:

- Use the following PowerShell command to move one of the secondary partitions that are in the same UD. [Move-ServiceFabricSecondaryReplica](https://learn.microsoft.com/en-us/powershell/module/servicefabric/move-servicefabricsecondaryreplica?view=azureservicefabricps).

    Example:

    ```powershell
    Move-ServiceFabricSecondaryReplica `
        -CurrentSecondaryNodeName '<current node name>' `
        -NewSecondaryNodeName '<new node name>' `
        -IgnoreConstraints $true `
        -ServiceName 'fabric:/...' `
        -TimeoutSec 1200 `
    ```

## Resolution

- Resolution will be in a future version release of Service Fabric. Product Group is actively working on fix.
