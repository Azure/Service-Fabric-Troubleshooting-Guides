# Service Fabric 8.2 Upgrade or Certificate Rollover May Fail due to ImageStoreService Error

## Symptoms

- Cluster is being upgraded to Service Fabric 8.2 or cluster certificate is being modified and is stuck on Upgrade Domain (UD) 0.
- 'fabric:/System/ImageStoreService' is in an 'Error' state.
- Some or all secondary replicas in ImageStoreService are down.
- Upgrade stuck (depending on how many replicas are down)
- Service Fabric Explorer (SFX) Warning Event: 00000000-0000-0000-0000-000000003000 SafetyCheck: EnsurePartitionQuorum
- SFX Error Event: 00000000-0000-0000-0000-000000003000 Partition is in quorum loss  

  ![](../media/sfx-imagestore-quorum-loss.png)


## Root Cause Analysis

- Service Fabric Product Group is currently investigating issue.

## Possible Mitigations

One of the following mitigation can be applied

- Option 1 - more complexity less impactful - [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to nodes with 'Down' ImageStoreService partitions. Open TaskManager and right-click on FileStoreService.exe to terminate process.  

    ![](../media/task-manager-filestoreservice-terminate.png)
- Option 2 - less complexity more impactful - From SFX, restart each node with a down partition *one at a time* ensuring prior node restart is complete.  

    ![](../media/sfx-node-restart.png)


## Resolution

- Issue to be resolved in future Service Fabric release.