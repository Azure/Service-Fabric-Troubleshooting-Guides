# VMSS Upgrade Policy Configuration and Service Fabric Quorum

## Overview

When you enable automatic OS image upgrades on an Azure Virtual Machine Scale Set (VMSS) hosting a Service Fabric cluster, the VMSS batching behavior **must be coordinated with Service Fabric's durability and quorum requirements**. An incorrectly configured upgrade policy can cause simultaneous node deallocation that violates quorum minimums, leading to cluster unavailability.

This guide explains how VMSS upgrade policy settings interact with Service Fabric quorum requirements and provides safe configuration patterns for all durability levels.

---

## The Problem: Unsafe Default Batching

By default, when neither `RollingUpgradePolicy` nor `useRollingUpgradePolicy` are explicitly configured, VMSS uses **topology-blind Update Domain (UD) batching**:

```json
"upgradePolicy": {
  "mode": "Automatic"
  // ❌ No RollingUpgradePolicy defined
  // ❌ No automaticOSUpgradePolicy defined → defaults to unsafe batching
}
```

**VMSS behavior:**
- Divides cluster instances into Update Domains (typically 5 UDs on Windows)
- Upgrades all instances in each UD **sequentially without respect to Service Fabric durability**
- Does not wait for SF replica re-homing or quorum recovery before moving to the next UD

**Example on a 5-node Silver durability cluster:**
- UD0 batch (1 node) → upgraded
- UD1 batch (1 node) → upgraded
- UD2 batch (1 node) → upgraded → **Only 2 nodes remain = QUORUM LOST**

---

## Service Fabric Durability Levels and Quorum Requirements

Service Fabric uses durability levels to define how many nodes can be unavailable while maintaining cluster quorum:

| Durability | Cluster Size | Minimum Nodes Required | Maximum Simultaneous Down |
|-----------|--------------|----------------------|--------------------------|
| **Bronze** | 1-2 | 1 | All (no UD coordination) |
| **Silver** | 3-4 | 3 of N | 1 node |
| **Silver** | 5+ | Floor(N/2)+1 | 1 node |
| **Gold** | 5+ | N-1 | 1 node (requires FabricRepairService) |
| **Platinum** | 9+ | N-1 | 0 (all nodes coordinated individually) |

### Affected Components

Quorum violations impact:

1. **Stateful system services** (managed by Service Fabric)
   - Failover Manager (FM)
   - Cluster Manager (CM)
   - Naming Service
   - Image Store Service

2. **User stateful services**
   - Any service with `TargetReplicaSetSize` > 1
   - Loses availability when quorum cannot be formed

3. **Seed nodes** (primary replica holders for system services)
   - SF system services must maintain quorum across seed nodes
   - Seed node unavailability directly prevents system service quorum
   - Typical configuration: 5 seed nodes on a 5-node cluster, 7 seed nodes on a 10-node cluster

4. **Lease layer**
   - Requires quorum for arbiter election
   - Node deallocation can cause lease layer quorum loss

---

## The Solution: Safe Upgrade Policy Configuration

### Configuration Structure

```json
{
  "properties": {
    "upgradePolicy": {
      "mode": "Automatic",
      "RollingUpgradePolicy": {
        "MaxBatchInstancePercent": 20,
        "MaxUnhealthyInstancePercent": 25,
        "MaxUnhealthyUpgradedInstancePercent": 25,
        "PauseTimeBetweenBatches": "PT5S"
      },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "useRollingUpgradePolicy": true,
        "disableAutomaticRollback": false
      }
    }
  }
}
```

### Parameter Definitions

#### `RollingUpgradePolicy`

- **MaxBatchInstancePercent** (required when using rolling upgrades)
  - Percentage of instances to upgrade in each batch
  - **Rule:** Must not exceed (ClusterSize - RequiredQuorum) / ClusterSize
  - Example: 5-node Silver cluster requires 3 nodes → max batch = (5-3)/5 = 40%, but safer is 20% (1 node)

- **MaxUnhealthyInstancePercent**
  - Maximum percentage of instances that can be unhealthy (missing, crashed) before upgrade halts
  - Typical value: 25%

- **MaxUnhealthyUpgradedInstancePercent**
  - Maximum percentage of instances in current batch that can fail during upgrade before halting
  - Typical value: 25%

- **PauseTimeBetweenBatches**
  - Time to wait between batch upgrades (allows SF to stabilize)
  - Example: `PT5S` = 5 seconds, `PT0S` = no pause

#### `automaticOSUpgradePolicy`

- **enableAutomaticOSUpgrade** (boolean)
  - Enable/disable automatic OS image patching

- **useRollingUpgradePolicy** (boolean) ⚠️ **CRITICAL**
  - **true**: VMSS respects `RollingUpgradePolicy` settings
  - **false** or omitted: VMSS ignores `RollingUpgradePolicy` and uses unsafe UD-based batching
  - Default: false (unsafe)

- **disableAutomaticRollback** (boolean)
  - true: Do not rollback if upgrade fails
  - false: Automatically rollback on failure (recommended)

---

## Safe Configuration by Durability Level

### Silver Durability (3-5 nodes)

**Requirement:** Never take down more than 1 node at a time.

```json
{
  "properties": {
    "upgradePolicy": {
      "mode": "Automatic",
      "RollingUpgradePolicy": {
        "MaxBatchInstancePercent": 20,
        "MaxUnhealthyInstancePercent": 25,
        "MaxUnhealthyUpgradedInstancePercent": 25,
        "PauseTimeBetweenBatches": "PT5S"
      },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "useRollingUpgradePolicy": true,
        "disableAutomaticRollback": false
      }
    }
  }
}
```

**Why:** 20% of 5 nodes = 1 node per batch, keeping 4 nodes available for system service quorum.

### Silver Durability (6+ nodes)

**Requirement:** Maintain 3+ nodes minimum.

```json
{
  "properties": {
    "upgradePolicy": {
      "mode": "Automatic",
      "RollingUpgradePolicy": {
        "MaxBatchInstancePercent": 33,
        "MaxUnhealthyInstancePercent": 25,
        "MaxUnhealthyUpgradedInstancePercent": 25,
        "PauseTimeBetweenBatches": "PT5S"
      },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "useRollingUpgradePolicy": true,
        "disableAutomaticRollback": false
      }
    }
  }
}
```

**Why:** 33% of 6-9 nodes allows controlled batching while maintaining quorum (e.g., 9 nodes: 3 per batch, 6 remain).

### Gold Durability (5+ nodes)

**Requirement:** Maintain N-1 nodes (coordinate with FabricRepairService).

```json
{
  "properties": {
    "upgradePolicy": {
      "mode": "Automatic",
      "RollingUpgradePolicy": {
        "MaxBatchInstancePercent": 20,
        "MaxUnhealthyInstancePercent": 25,
        "MaxUnhealthyUpgradedInstancePercent": 25,
        "PauseTimeBetweenBatches": "PT10S"
      },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "useRollingUpgradePolicy": true,
        "disableAutomaticRollback": false
      }
    }
  }
}
```

**Why:** Gold durability requires tighter coordination. Use 20% batch size and longer pause times (10s) to allow FabricRepairService to coordinate deactivations.

### Platinum Durability (9+ nodes)

**Requirement:** Coordinate all nodes individually via FabricRepairService.

```json
{
  "properties": {
    "upgradePolicy": {
      "mode": "Automatic",
      "RollingUpgradePolicy": {
        "MaxBatchInstancePercent": 11,
        "MaxUnhealthyInstancePercent": 11,
        "MaxUnhealthyUpgradedInstancePercent": 11,
        "PauseTimeBetweenBatches": "PT15S"
      },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "useRollingUpgradePolicy": true,
        "disableAutomaticRollback": false
      }
    }
  }
}
```

**Why:** Platinum requires individual node coordination. Small batch size (11%) and longer pause times (15s) allow FabricRepairService to work properly.

---

## How These Settings Relate to Service Fabric Quorum

### The Coordination Flow

1. **VMSS initiates upgrade batch** (based on `MaxBatchInstancePercent`)
   - Stops N instances

2. **Service Fabric Failover Manager (FM) detects node unavailability**
   - Marks nodes as down
   - Initiates replica re-homing for stateful services

3. **Stateful service replicas move to surviving nodes**
   - Primary replicas elect new leaders
   - Secondary replicas ensure replication

4. **System services maintain quorum** (if enough nodes remain)
   - FM can form quorum
   - CM can form quorum
   - Lease layer maintains quorum

5. **FabricRepairService (Gold/Platinum) coordinates deactivations**
   - Approves or delays deactivation based on service quorum state

6. **VMSS continues to next batch** (after `PauseTimeBetweenBatches`)
   - Only if Azure health probes pass (instance is running)

### Critical Gap: VMSS Health Probes ≠ Service Fabric Quorum

⚠️ **Important:** Azure health probes (used by load balancers) only check if a VM instance is running. They do NOT validate Service Fabric quorum status.

```
Azure Health Probe: "Is the instance running?" → ✅ Yes
Service Fabric Quorum: "Can system services form quorum?" → ❌ No (2 of 3 quorum-required services down)

VMSS sees ✅ and proceeds to next batch without waiting for SF recovery.
```

This is why `PauseTimeBetweenBatches` is critical — it gives Service Fabric time to re-home replicas and recover quorum between batches.

---

## Troubleshooting: How to Detect Unsafe Configuration

### Symptom 1: Cluster Becomes Unresponsive During OS Updates

**Signs:**
- FM and CM stop responding
- No new service deployments possible
- Nodes marked as Down in Service Fabric Explorer (SFX)
- Multiple nodes simultaneously gone

**Root cause:**
- `useRollingUpgradePolicy` is false or omitted
- VMSS used UD-based batching instead of rolling policy
- More nodes were deactivated than Service Fabric quorum allows

**Verification:**
1. Check ARM/Bicep template or deployed VMSS configuration:
   ```powershell
   $vmss = Get-AzVmss -ResourceGroupName <RG> -VMScaleSetName <ScaleSetName>
   $vmss.VirtualMachineProfile.StorageProfile.ImageReference | Format-List *
   $vmss.UpgradePolicy | ConvertTo-Json -Depth 10
   ```
2. Look for `useRollingUpgradePolicy` in `automaticOSUpgradePolicy`
3. Verify `RollingUpgradePolicy.MaxBatchInstancePercent` exists

### Symptom 2: System Services (FM, CM) Down with Multiple Nodes Healthy

**Signs:**
- Nodes appear healthy in SFX
- FM and Naming Service unavailable
- Seed nodes are down
- Cluster health = Error

**Root cause:**
- All seed nodes were in the same UD
- VMSS upgraded all of them together
- System service quorum lost (seed nodes are primary replicas)

**Verification:**
1. Check current node statuses:
   ```powershell
   Connect-ServiceFabricCluster -ConnectionEndpoint <cluster-endpoint>
   Get-ServiceFabricNode | Select NodeName, NodeStatus
   ```
2. Identify seed nodes in cluster manifest:
   ```powershell
   Get-ServiceFabricClusterManifest | Out-File manifest.xml
   # Look for <Votes> section with seed node names
   ```
3. If multiple seed nodes are Down, seed node batching violated quorum

### Symptom 3: Stateful Services Lose Quorum

**Signs:**
- Service partitions show "No quorum" in SFX
- Service calls fail with quorum loss errors
- Happens during automated OS upgrade window

**Root cause:**
- Too many replicas deactivated in single batch
- `MaxBatchInstancePercent` exceeds safe threshold for cluster size

**Verification:**
1. Compare batching to service replication:
   ```powershell
   Get-ServiceFabricService -ApplicationName <app> | Select ServiceName, ServiceTypeName, ServiceStatus
   Get-ServiceFabricPartition -ServiceName <service> | Select PartitionId, PartitionStatus, ServiceName
   ```
2. If PartitionStatus = "InQuorumLoss", a batch took down too many replicas

---

## Impact on Different Service Fabric Components

### Failover Manager (FM)

- **System service** that manages node state and partition quorum
- **Quorum requirement:** Needs primary + 1 secondary minimum (3+ replicas total on 5+ node clusters)
- **Impact of unsafe batching:** If FM loses quorum, cluster management stops entirely
- **Recovery:** Requires manual intervention (cluster restart possible)

### Cluster Manager (CM)

- **System service** managing application deployments
- **Quorum requirement:** Same as FM (3+ replicas)
- **Impact:** Cannot process service creation, upgrades, or deletions
- **Symptom:** "Unable to reach Cluster Manager" errors from Azure Portal

### Naming Service

- **System service** for service discovery
- **Quorum requirement:** N/2+1 (5 nodes → need 3)
- **Impact:** Service discovery fails, applications cannot resolve endpoints

### User Stateful Services

- **Replica distribution:** Typically 1-3 replicas per partition
- **Quorum for replica set:** (ReplicaCount / 2) + 1
- **Impact of single batch:** If batch size > (ReplicaCount - QuorumSize), service loses quorum
- **Example:** 5-node cluster, service with 5 replicas, batch = 20% (1 node) → safe (4 remain, need 3)
- **Example:** 5-node cluster, service with 3 replicas spread across 3 nodes, batch = 40% (2 nodes) → unsafe (1 remains, need 2)

### Seed Nodes

- **Role:** Primary replicas for system services (FM, CM, Naming Service)
- **Quorum requirement:** Majority of seed nodes must be healthy
- **Typical config:** 5 seed nodes on 5-node cluster, 7 on 10-node cluster
- **Impact:** If > 50% of seed nodes in same UD and batch size allows all in one batch, system service quorum lost
- **Safe config:** Ensure `MaxBatchInstancePercent` < 50% to never take down majority in single batch

### Lease Layer

- **Background:** Maintains membership view using quorum voting
- **Impact:** Lease quorum loss → nodes marked as Down (even if running)
- **Related to:** Seed node health (seed nodes participate in lease quorum)

---

## Step-by-Step: Verifying and Fixing Configuration

### Step 1: Check Current Upgrade Policy

```powershell
# Get VMSS configuration
$vmss = Get-AzVmss -ResourceGroupName <ResourceGroup> -VMScaleSetName <ScaleSetName>

# View upgrade policy
$vmss.UpgradePolicy | ConvertTo-Json -Depth 10

# Check for the critical flag
$vmss.UpgradePolicy.AutomaticOSUpgradePolicy.UseRollingUpgradePolicy
```

**Expected output if safe:**
```
UseRollingUpgradePolicy: True
RollingUpgradePolicy: {MaxBatchInstancePercent: 20, ...}
```

**If false or missing:** Your configuration is unsafe.

### Step 2: Calculate Safe Batch Size

```
SafeMaxBatchPercent = 100 * (ClusterSize - RequiredQuorum) / ClusterSize

Examples:
- 5-node Silver: (5-3)/5 = 40%, but recommend 20% (1 node)
- 10-node Silver: (10-6)/10 = 40%, recommend 25% (2-3 nodes)
- 5-node Gold: (5-4)/5 = 20%
- 9-node Platinum: (9-8)/9 = 11%
```

### Step 3: Update Template (ARM or Bicep)

**ARM Template:**
```json
{
  "type": "Microsoft.Compute/virtualMachineScaleSets",
  "apiVersion": "2021-03-01",
  "name": "[variables('vmScaleSetName')]",
  "properties": {
    "upgradePolicy": {
      "mode": "Automatic",
      "RollingUpgradePolicy": {
        "MaxBatchInstancePercent": 20,
        "MaxUnhealthyInstancePercent": 25,
        "MaxUnhealthyUpgradedInstancePercent": 25,
        "PauseTimeBetweenBatches": "PT5S"
      },
      "automaticOSUpgradePolicy": {
        "enableAutomaticOSUpgrade": true,
        "useRollingUpgradePolicy": true,
        "disableAutomaticRollback": false
      }
    }
  }
}
```

**Bicep Template:**
```bicep
resource vmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: vmScaleSetName
  location: location
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
      rollingUpgradePolicy: {
        maxBatchInstancePercent: 20
        maxUnhealthyInstancePercent: 25
        maxUnhealthyUpgradedInstancePercent: 25
        pauseTimeBetweenBatches: 'PT5S'
      }
      automaticOSUpgradePolicy: {
        enableAutomaticOSUpgrade: true
        useRollingUpgradePolicy: true
        disableAutomaticRollback: false
      }
    }
  }
}
```

### Step 4: Deploy Updated Configuration

```powershell
# Update VMSS configuration
$vmss.UpgradePolicy.AutomaticOSUpgradePolicy.UseRollingUpgradePolicy = $true
$vmss.UpgradePolicy.RollingUpgradePolicy.MaxBatchInstancePercent = 20
$vmss.UpgradePolicy.RollingUpgradePolicy.MaxUnhealthyInstancePercent = 25
$vmss.UpgradePolicy.RollingUpgradePolicy.MaxUnhealthyUpgradedInstancePercent = 25
$vmss.UpgradePolicy.RollingUpgradePolicy.PauseTimeBetweenBatches = "PT5S"

Update-AzVmss -ResourceGroupName <ResourceGroup> -Name <ScaleSetName> -VirtualMachineScaleSet $vmss
```

### Step 5: Verify Cluster Health During Next Upgrade

Monitor the cluster during the next automatic upgrade:

```powershell
# Watch node status
while($true) {
  Get-ServiceFabricNode | Select NodeName, NodeStatus
  Get-ServiceFabricApplicationHealth -ApplicationName "fabric:/System" | Select ApplicationName, AggregatedHealthState
  Start-Sleep -Seconds 10
}
```

**Healthy behavior:**
- 1 node goes Down
- Other nodes stay healthy
- System services maintain quorum (FM, CM, Naming Service all healthy)
- Next batch begins after `PauseTimeBetweenBatches`

---

## Related Concepts

### Service Fabric Durability vs. Reliability

- **Durability** (Bronze/Silver/Gold/Platinum): How many nodes can be down simultaneously
- **Reliability** (TargetReplicaSetSize): How many replicas each service has
- Both must be considered for safe configuration

### Automatic vs. Manual Upgrades

- **Automatic:** VMSS controlled, no human approval
- **Manual:** Human reviews and approves each batch
- **Recommended for production:** Manual upgrades to allow monitoring between batches

### Update Domains vs. Fault Domains

- **Update Domains (UD):** Logical grouping for upgrade sequencing
- **Fault Domains (FD):** Physical grouping for failure isolation
- **VMSS default:** Uses UDs for batching; with `useRollingUpgradePolicy: true`, uses FDs (respects custom batch sizes)

---

## Prevention Checklist

- [ ] Verify `useRollingUpgradePolicy` is explicitly set to `true`
- [ ] Verify `RollingUpgradePolicy` section exists and is not empty
- [ ] Calculate `MaxBatchInstancePercent` based on cluster size and durability level
- [ ] Set `PauseTimeBetweenBatches` to at least 5 seconds (longer for Gold/Platinum)
- [ ] Test configuration on non-production cluster first
- [ ] Monitor first automated upgrade cycle for unexpected node down events
- [ ] Document safe configuration for future deployments
- [ ] Include upgrade policy settings in Infrastructure-as-Code (Bicep/Terraform)
- [ ] Review cluster manifest to identify seed node distribution
- [ ] Validate system service quorum after each upgrade cycle

---

## See Also

- [Service Fabric Cluster Capacity Planning](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-capacity)
- [Automatic OS Image Upgrades on VMSS](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade)
- [Service Fabric Durability Characteristics](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-disaster-recovery#durability-characteristics)
- [FabricRepairService Coordination](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-patch-orchestration-application)
