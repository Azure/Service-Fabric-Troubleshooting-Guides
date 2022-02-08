---
eng.ms.tsg.applicableTo: Public, MoonCake, BlackForest, FairFax, USNAT, USSEC, 
eng.ms.tsg.requireJIT: Yes
eng.ms.tsg.ProductionTarget: Service Fabric 
eng.ms.tsg.owningTeam: Service Fabric - Service
name: TSG Partition with BackupPolicy enabled; stuck at change role during reconfiguration causing availability loss
---
# Partition with BackupPolicy enabled; stuck at change role during reconfiguration causing availability loss

Clusters which have Backup Restore Service enabled and backup policies set for backing up data for stateful services, may encounter situation where partition reconfiguration is stuck. This occurs if a full backup is being taken for large data set while a reconfiguration also get triggered at the same time.

## Symptom

1. Reconfiguration is stuck. Waiting for response from the local replica
2. The api IStatefulServiceReplica.ChangeRole(S) on node <nodename> is stuck. Start Time (UTC): <change role start time>.
3. BackupManager.CallBackupCallbackAsync duration is greater than expected 00:05:00

## Detection in SFX

![Reconfiguration Stuck](/images/BRS/ReconfigStuck.png)

![Backup Callback Stuck health warning](/images/BRS/BackupCallbackStuck.png)

## Detection with Powershell

1. Connect to the cluster

```powershell
PS C:\> Connect-ServiceFabricCluster -ConnectionEndpoint @(your cluster endpoint') -X509Credential -FindType FindByThumbprint -FindValue your cert thumbprint -StoreLocation CurrentUser -StoreName 'MY' -ServerCommonName @(your server cert commonname)
```

2. Get health of replica stuck in change role

```powershell
PS C:\> Get-ServiceFabricReplicaHealth -PartitionId a44ff156-f8c0-4da8-ad0f-11c3428f6686 -ReplicaOrInstanceId 132884468834343587`

PartitionId           : a44ff156-f8c0-4da8-ad0f-11c3428f6686
ReplicaId             : 132884468834343587
AggregatedHealthState : Warning
UnhealthyEvaluations  :
                        'System.RAP' reported Warning for property 'IStatefulServiceReplica.ChangeRole(S)Duration'.
                        The api IStatefulServiceReplica.ChangeRole(S) on node _Node_0 is stuck. Start Time (UTC): 2022-02-04 11:20:18.656.

HealthEvents          :
                        SourceId              : System.RA
                        Property              : State
                        HealthState           : Ok
                        SequenceNumber        : 132884468836533547
                        SentAt                : 2/4/2022 11:14:43 AM
                        ReceivedAt            : 2/4/2022 11:14:43 AM
                        TTL                   : Infinite
                        Description           : Replica has been created on_Node_0.
                        For more information see: <http://aka.ms/sfhealth>
                        RemoveWhenExpired     : False
                        IsExpired             : False
                        HealthReportID        : RA_7.0_1002
                        Transitions           : Error->Ok = 2/4/2022 11:14:43 AM, LastWarning = 1/1/0001 12:00:00 AM

                        SourceId              : System.RAP
                        Property              : IStatefulServiceReplica.ChangeRole(S)Duration
                        HealthState           : Warning
                        SequenceNumber        : 132884472436518845
                        SentAt                : 2/4/2022 11:20:43 AM
                        ReceivedAt            : 2/4/2022 11:20:43 AM
                        TTL                   : Infinite
                        Description           : The api IStatefulServiceReplica.ChangeRole(S) on node _Node_0 is stuck. Start Time (UTC): 2022-02-04 11:20:18.656.
                        RemoveWhenExpired     : False
                        IsExpired             : False
                        HealthReportID        : RAP_7.0_1001
                        Transitions           : Error->Warning = 2/4/2022 11:20:43 AM, LastOk = 1/1/0001 12:00:00 AM
                        
                        SourceId              : BackupManager.CallBackupCallbackAsync
                        Property              : ReplicatorHealthBackupCallbackSlow
                        HealthState           : Warning
                        SequenceNumber        : 132884475057674055
                        SentAt                : 2/4/2022 11:25:05 AM
                        ReceivedAt            : 2/4/2022 11:25:05 AM
                        TTL                   : Infinite
                        Description           : BackupManager.CallBackupCallbackAsync duration is greater than expected 00:05:00
                        RemoveWhenExpired     : False
                        IsExpired             : False
                        HealthReportID        : 
                        Transitions           : Error->Warning = 2/4/2022 11:25:05 AM, LastOk = 1/1/0001 12:00:00 AM
                        
                        SourceId              : System.RA
                        Property              : Reconfiguration
                        HealthState           : Warning
                        SequenceNumber        : 132884475730311255
                        SentAt                : 2/4/2022 11:26:13 AM
                        ReceivedAt            : 2/4/2022 11:26:13 AM
                        TTL                   : Infinite
                        Description           : Reconfiguration is stuck. Waiting for response from the local replica
                        
                        Reconfiguration start time: 2022-02-04 11:20:18.510. Reconfiguration phase start time: 2022-02-04 11:20:18.510.
                        
                        For more information see: http://aka.ms/sfhealth
                        RemoveWhenExpired     : False
                        IsExpired             : False
                        HealthReportID        : RA_7.0_1000
                        Transitions           : Error->Warning = 2/4/2022 11:26:13 AM, LastOk = 1/1/0001 12:00:00 AM 
```

## Mitigation

Remove the primary replica stuck in demoting to ActiveSecondary
Using Powershell:

1. Connect to the cluster

```powershell
PS C:\> Connect-ServiceFabricCluster -ConnectionEndpoint @(your cluster endpoint') -X509Credential -FindType FindByThumbprint -FindValue your cert thumbprint -StoreLocation CurrentUser -StoreName 'MY' -ServerCommonName @(your server cert commonname)
```

2. Remove the replica stuck in change role

```powershell
PS C:\> Remove-ServiceFabricReplica -NodeName _Node_0 -PartitionId a44ff156-f8c0-4da8-ad0f-11c3428f6686 -ReplicaOrInstanceId 132884468834343587 -ForceRemove

RemoveReplica scheduled node _Node_0 for replica 132884468834343587 of partition a44ff156-f8c0-4da8-ad0f-11c3428f6686.
```

## Build Versions with the Fix for this issue

Upgrade your cluster to following versions or higher

For clusters on 8.1 builds – **8.1.355.9590**

For clusters on 8.2 builds – **8.2.1486.9590**
