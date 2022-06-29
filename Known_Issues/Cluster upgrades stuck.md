---
name: Cluster upgrades stuck
---

## Problem Description/Impact

 Service Fabric clusters configured with automatic or manual runtime upgrades may get stuck in an upgrade domain without impacting customer workloads. Effected Service Fabric runtime versions include:
	•	8.2.1235.9590
	•	8.2.1363.9590
	•	8.2.1486.9590
	•	8.2.1571.9590
	•	8.2.1620.9590
	•	9.0.1017.9590
	•	9.0.1028.9590

## How to identify Service Fabric runtime version

 The runtime version can be verified based on the type of Service Fabric cluster using the following:

	•	Azure Service Fabric cluster
	Check the “Service Fabric Version” under “Overview” by logging into Azure Portal   See Visualizing your cluster using Azure Service Fabric Explorer

	•	Standalone Service Fabric cluster
	Get-ServiceFabricClusterConfiguration (ServiceFabric) | Microsoft Docs


## How to identify a cluster upgrade is stuck in Service Fabric

 Validate if your cluster runtime upgrade is stuck making any progress across upgrade domains by:

	1.	Service Fabric Explorer:

		•	In the details tab at the cluster level check the Start Timestamp, Upgrade state and the Code Version to which the cluster is upgrading to. If the Start Timestamp is >24 hours and Upgrade state continues to not change from “Upgrade in Progress” then follow the mitigation steps listed under “Required Action from customer”.

	2.	PowerShell:

		•	Connect to the Service Fabric cluster using the command
		Connect-ServiceFabricCluster

		•	Execute the below command to retrieve the current progress of the upgrade.
		Get-ServiceFabricClusterUpgrade 
		If the StartTimestampUtc is >24 hours and Upgrade state continues to not change from “Upgrade in Progress”. Please follow the mitigation steps listed under “Required Action from customer”


## Required Action from customer

 Take the following steps to mitigate the issue:

	1)	From the PowerShell connect to Service Fabric cluster using the command 
	Connect-ServiceFabricCluster

	2)	Get the PartitionId of ClusterManagerService using the command
	Get-ServiceFabricPartition

	Eg. Get-ServiceFabricPartition -ServiceName fabric:/System/ClusterManagerService

	3)	Restart ClusterManagerService primary replica using the command
	Restart-ServiceFabricReplica

	Eg. Restart-ServiceFabricReplica -PartitionId 00000000-0000-0000-0000-000000002000 -ReplicaKindPrimary -ServiceName fabric:/System/ClusterManagerService


## When will the Fix for this issue be rolled out?

 Service Fabric is rolling out a fix as part of 9.0 CU2 and 8.2 CU4 in July that resolves the stuck upgrade problem once upgraded to latest versions.
