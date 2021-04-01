# Shared Log Writes Throttled

## Symptoms

- Stateful Service is experiencing high write transaction latencies.
- Stateful Service is receiving high count of Timeout Exceptions for write transactions.
- 'SharedLogWriteThrottled' platform event is raised for the node experiencing the issue. This event is visible on the Events tab of SFX:

![SharedLogWriteThrottled Event](../media/SharedLogWriteThrottled.png)


## Possible Causes

Reliable Collections use Write Ahead Log to persist transactions for a Stateful Service. The write ahead log is comprised of the highly performant shared log and the replica dedicated log. The shared log is shared by all the replicas on the node. All transaction records are first written to this shared log. Later, in the background, these records are extracted and flushed to the respective dedicated replica logs.
Sometimes the shared log may reach its near full capacity (90%). When this happens, the writes are throttled to allow the background task to flush the records to the dedicated log. During this time, the write performance is degraded due to throttling.
This may occur due to any of the following:
1.	**Occasional burst in the write rate.** Thus, the rate at which the background task is flushing the records to the dedicated log lags behind the rate at which the shared log is getting filled. This condition is usually transient and will clear up once the write rate is stabilized.
2.	**Write to the dedicated log failed.** The shared log is implemented as a circular buffer. So, if a dedicated log write fails, the record may block the flushing of the other records which may eventually lead to the shared log full.
3.	**Replica was aborted.** When the replica is aborted, sometimes the log doesn’t get the chance to flush the records to the replica dedicated log. Thus, the records for the replica remains in the shared log, which may block the shared log truncation and eventually lead to the shared log full.

## Mitigation

The 'SharedLogWriteThrottled' platform event consists of the following information:
- **SharedLogStream:** This field displays the guid of the shared log that is throttled.
- **BlockingStreamInfo:** This field provides information about the **Partition**, **Replica** and the **Stream Id**.

If the shared log throttling is due to condition (1) above, usually, it should get unthrottled after some time and you should see the following event in the SFX:

![SharedLogWriteUnthrottled Event](../media/SharedLogWriteUnthrottled.png)

However, if the problem persists for some time ( > 1 min), then try to restart the replica identified by the **Replica** in the **BlockingStreamInfo**.

 ```powershell
 Restart-ServiceFabricReplica -NodeName [NodeName] -PartitionId [PartitionId] -ReplicaOrInstanceId [ReplicaId]
 ```
for more details, refer [Restart-ServiceFabricReplica](https://docs.microsoft.com/en-us/powershell/module/servicefabric/restart-servicefabricreplica)
___

If the replica is already closed, or restarting the replica doesn’t help then perform the following steps:
- Deactivate the node with intent restart  
 
   ```powershell
   Disable-ServiceFabricNode -NodeName [NodeName] -Intent Restart
   ```
   
  for more details, refer [Disable-ServiceFabricNode](https://docs.microsoft.com/en-us/powershell/module/servicefabric/disable-servicefabricnode)
  
- Wait for the node to become disabled before restarting the node. Use SFX or the powershell [Get-ServiceFabricNode](https://docs.microsoft.com/en-us/powershell/module/servicefabric/get-servicefabricnode) cmdlet to view the disabling status of the node.

  ```powershell
  Get-ServiceFabricNode -NodeName [NodeName]
  ```
  
- Restart the VM/Node. This can be done from VMSS for SFRP clusters.
- After the restart has been completed, enable the node using the powershell [Enable-ServiceFabricNode](https://docs.microsoft.com/en-us/powershell/module/servicefabric/enable-servicefabricnode) cmdlet.
  
  ```powershell
  Enable-ServiceFabricNode -NodeName [NodeName]
  ```
