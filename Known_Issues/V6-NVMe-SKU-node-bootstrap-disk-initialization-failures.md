# V6 (NVMe) VM SKU node bootstrap / data path initialization failures

## Summary

Newer Azure VM SKUs (the `_v6` families and other NVMe-capable sizes) present their
local temporary disk as a **raw, unformatted NVMe device** instead of the older
SCSI-based temporary disk. Service Fabric, by default, uses the local temporary
disk for the node data path (`FabricDataRoot` / `dataPath`). When the NVMe disk is
not initialized and formatted, the node bootstrap agent cannot create the data
path, the node fails to come up, and the cluster can become **stuck in `Updating` /
`Upgrading`** after the deployment or SKU change.

This most commonly appears immediately after a node type's VM SKU is changed or
scaled to a `_v6` size (for example `Standard_D*ads_v6`), or after adding a new
node type that uses an NVMe-capable SKU.

## Symptoms

- Cluster resource is stuck in **`Updating`** (classic / SFRP clusters) or node
  type provisioning stalls and never completes.
- **Newly provisioned VMSS instances / new node types are not added to the
  cluster** — the deployment may report success, but the nodes never join.
- New or reimaged nodes never join the cluster / do not appear in Service Fabric
  Explorer (SFX).
- The Service Fabric VM extension (node bootstrap agent) reports errors about a
  **missing data drive / data path** or an unavailable drive letter.
- The problem starts right after a node type SKU was changed to a `_v6` size, or a
  new node type using an NVMe-capable SKU was added.

## Cause

`_v6` and other NVMe-capable VM sizes deliver **raw, unformatted local NVMe temp
disks**. Unlike previous D/E series VMs (which exposed a pre-formatted SCSI
temporary disk), the guest OS sees the NVMe local disk with `PartitionStyle = RAW`
until it is explicitly initialized, partitioned, and formatted after the VM starts.

Because Service Fabric places the node data path on the local disk by default, a
raw/uninitialized NVMe disk means the data path cannot be created and node
bootstrap stalls. The disk-initialization logic that worked for SCSI temporary
disks does not automatically handle the NVMe device, so required partitions or the
file system are never created.

> Although NVMe local disks are most commonly associated with `_v6` SKUs, some
> earlier or non-`v6` series also use NVMe (for example `Fxmsv2-series` and
> `Lsv2`+). Any VM SKU with local NVMe disks is subject to the same
> initialization considerations.

## Applies to

- Classic Service Fabric clusters (SFRP) using a `_v6` / NVMe-capable node type SKU.
- Service Fabric managed clusters (SFMC) — **managed data disk support does not
  initialize NVMe disks automatically**; NVMe disks must be initialized and
  formatted yourself (including when the temporary disk is used for `dataPath`).
- Any node type whose SKU exposes local storage over the NVMe interface.

## Detection

1. **Confirm the node type SKU.** Check whether the affected node type uses a
   `_v6` size (or any NVMe-capable size). In the Azure portal, review the
   underlying Virtual Machine Scale Set (VMSS) SKU, or:

   ```powershell
   # Classic: inspect the VMSS backing the node type
   Get-AzVmss -ResourceGroupName <rg> -VMScaleSetName <nodeTypeName> |
       Select-Object -ExpandProperty Sku
   ```

2. **Check for raw NVMe disks on the VM.** Use the VMSS **Run Command**, serial
   console, or RDP to a node instance and run:

   ```powershell
   # Any disk still RAW has not been initialized/formatted
   Get-Disk | Select-Object Number, FriendlyName, PartitionStyle, BusType, HealthStatus

   # List NVMe physical disks specifically
   Get-PhysicalDisk | Where-Object BusType -eq 'NVMe' |
       Select-Object DeviceId, FriendlyName, MediaType, Size, BusType
   ```

   A local NVMe disk reporting `PartitionStyle = RAW` (and no data drive letter
   for the Service Fabric data path) confirms this issue.

   Real output captured from a fresh `Standard_D4ads_v6` VM (Windows Server 2022
   Azure Edition) shows the local temp NVMe disk as `RAW`:

   ```text
   Number FriendlyName                  PartitionStyle BusType HealthStatus
   ------ ------------                  -------------- ------- ------------
        1 Microsoft NVMe Direct Disk v2 RAW            NVMe    Healthy
        0 Virtual_Disk NVME Premium     GPT            NVMe    Healthy
   ```

   Disk 1 (`Microsoft NVMe Direct Disk v2`) is the local temp disk and is `RAW` /
   uninitialized — so the Service Fabric data path (for example `D:\SvcFab`)
   cannot be created.

3. **Review the VM extension / bootstrap logs** on the node for messages about a
   missing data drive, missing drive letter, or a data path that could not be
   created.

## Sample errors and log entries

The exact wording varies by runtime/extension version; use these as representative
signatures rather than exact-match strings.

### Cluster / deployment level

- The Service Fabric cluster resource remains in `Updating` and the node type /
  VMSS extension provisioning reports a failed or timed-out state.
- The Service Fabric VM extension (node bootstrap agent) reports a **failed**
  handler status referencing disk / data-drive initialization.

### Service Fabric VM extension — node bootstrap / managed-disk initialization

Found in the node's VM extension / `ServiceFabricNodeBootstrapAgent` trace files
(commonly under `C:\WindowsAzure\Logs\Plugins\...\` — exact path and version
folder vary by extension build). LUN, drive letter, and label values shown below
are examples (the label is caller-supplied); the message text itself is emitted
by the extension's disk-initialization script:

```text
Mounting temporary disk with LUN <lun>, drive letter <driveLetter> and label <label>
Temporary disk NVMeDirect not found with LUN <lun> (This expected in vms < v6 (non NVMe) or skus without temp disk)
Data disk not found with LUN <lun>
Partition not found for data disk LUN <lun>
Exception in Powershell Script
ManagedDiskInitializationFailed
```

The extension fails because the data path (for example `D:\SvcFab`) lives on a
temp disk that was never initialized/formatted, so the drive letter does not
exist. The node bootstrap agent surfaces a `DirectoryNotFoundException` when it
tries to create the data root directory:

```text
DataRoot directory used in this node is different from specified on the settings.
dataRootDirectory D:\SvcFab  PublicSettings.DataPath: D:\SvcFab

ERROR:
Microsoft.Azure.ServiceFabric.Extension.Core.AgentException: Service Fabric
data drive for "dataPath":D:\SvcFab may not be available. Check
whether the drive is mounted correctly. Error:
System.IO.DirectoryNotFoundException: Could not find a part of the path 'D:'.
   at System.IO.__Error.WinIOError(Int32 errorCode, String maybeFullPath)
   at System.IO.Directory.InternalCreateDirectory(String fullPath, String path, Object dirSecurityObj, Boolean checkHost)
   at System.IO.Directory.InternalCreateDirectoryHelper(String path, Boolean checkHost)
   at Microsoft.Azure.ServiceFabric.Extension.Core.NodeBootstrapAgent.VerifyDataRootDriveAvailable()
   at Microsoft.Azure.ServiceFabric.Extension.Core.NodeBootstrapAgent.MoveNext()
--- End of stack trace from previous location where exception was thrown ---
   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
```

On other affected nodes of the same node type, the extension may instead report a
retry/wait while the first (failing) instance holds the bootstrap mutex:

```text
Mutex already exists; waiting up to 00:03:00 for another instance of this process to exit
```

### Guest agent logs (on the VM)

The Windows guest agent logs the Service Fabric extension failure with a message
indicating a missing data-drive path. On the affected node, the relevant logs are:

- Guest agent log: `C:\WindowsAzure\Logs\WaAppAgent.log`
- Service Fabric extension handler logs:
  `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\<version>\`
- Extension status (`.status` files):
  `C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\<version>\Status\`

The same events are also surfaced in platform telemetry (for example the
`GuestAgentGenericLogs` table) filtered to the affected cluster's subscription /
resource group with `EventName contains 'ServiceFabric'`.

### Fabric / data-path driver (post-bootstrap)

If the node partially bootstraps but the data path cannot be opened on the raw
NVMe device, the shared-log / data-path driver can fail to open the disk device
(the NVMe device interface path is not resolved correctly), which prevents
`Fabric.exe` from opening the node data root. This manifests as the node failing
to open and returning to the "not up" state after each attempt.

## Resolution

Pick the option that matches your cluster type and urgency.

### Option A — Fast mitigation: revert the node type SKU to a `_v5` (non-NVMe) size

The quickest way to restore a stuck cluster is to move the node type back to a
comparable **`_v5`** (or other SCSI temp-disk) SKU, which exposes a pre-formatted
temporary disk that Service Fabric can use without extra initialization.

- Classic (SFRP): update the node type SKU in the ARM template / deployment from
  the `_v6` size back to the equivalent `_v5` size and redeploy.
- Ensure the target SKU still has a local temporary disk of **32 GB or more** — SF
  requires local temporary storage; SKUs with **no temp storage are not supported**.

### Option B — Initialize the NVMe disk with a Custom Script Extension (CSE)

To keep using a `_v6` / NVMe SKU, add a **Custom Script Extension** to the VMSS
that installs and runs the NVMe initialization logic **before** Service Fabric
needs the data path. Configure the same logic to run after later VM starts and
reimages as described below. This applies to both classic and managed clusters.

Because NVMe local (temp) disks are transient, the disk must be re-initialized
after user-initiated stops, deallocations, planned maintenance, and reimage
events. The CSE must therefore be **idempotent** — it should only initialize a
disk that is still RAW and skip disks that are already formatted.

> **Do not use `D:` for a new configuration.** `D:` is the historical Service
> Fabric default, but another device such as the DVD/CD-ROM can claim it before
> the initialization script runs. Use a higher, explicitly configured drive
> letter such as `S:` and set the Service Fabric extension's `dataPath` to the
> same location (for example, `S:\SvcFab`). Verify that the selected letter is
> free on every VM SKU and image used by the node type.

Confirmed by repro: on `_v6` VMs the DVD/CD-ROM drive frequently already owns
`D:`. Creating the data partition succeeds, but assigning `D:` to it fails with
`The requested access path is already in use.` A script that targets `D:` must
therefore move the DVD drive to another letter first — this is the same reason
the Service Fabric VM extension contains "change DVD drive letter" logic. Using
`S:` avoids the collision entirely and is the recommended configuration.

This follows the existing Service Fabric managed-cluster convention:
[`S:` is the default data-disk letter, and `C:` and `D:` are reserved](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-modify-node-type#configure-the-service-fabric-data-disk-drive-letter).
For an existing node type, do not initialize `S:` while its Service Fabric
configuration still points to `D:\SvcFab`. Configure both values together when
creating the node type. If the node type's data drive letter cannot be changed
(as with a managed-cluster node type after creation), create a replacement node
type and migrate the workload instead.

Use the maintained Azure VM examples as the starting point instead of copying a
full disk-management script into this guide:

- **Windows:** [Format and initialize temp NVMe disks with Azure PowerShell](https://learn.microsoft.com/azure/virtual-machines/enable-nvme-temp-faqs#how-can-i-format-and-initialize-temp-nvme-disks-in-windows-when-i-create-a-vm)
- **Linux:** [Format and initialize temp NVMe disks in Linux](https://learn.microsoft.com/azure/virtual-machines/enable-nvme-temp-faqs#how-can-i-format-and-initialize-temp-nvme-disks-in-linux)

A full inline copy is not needed here and would drift from the maintained Azure
VM guidance. The Windows example creates a storage pool from the available
`NVMe Direct Disk` devices and uses `-AssignDriveLetter`. The Linux example
combines the temporary NVMe disks into RAID 0 and accepts the file-system type
and mount point as arguments; pass the mount point configured for the Service
Fabric data path.

**The referenced examples are not drop-in for Service Fabric.** They are written
for an interactive, first-boot VM scenario, so adapt them before using them in a
CSE:

- **Assign a fixed drive letter.** `-AssignDriveLetter` takes the next free
  letter, which varies by SKU, image, and disk count, so `dataPath` cannot be
  pinned. Use `-DriveLetter S` instead — the two parameters are mutually
  exclusive, so remove `-AssignDriveLetter` rather than adding to it. Configure
  `dataPath` as `S:\SvcFab`.
- **Make it idempotent.** The Windows example has no RAW check and fails on a
  second run (`New-StoragePool` fails if the pool exists, and
  `Get-PhysicalDisk -CanPool $True` returns nothing once the disks are pooled).
  Guard on partition style / existing volume and exit successfully when the data
  path is already present. The Linux example already performs this check.
- **Format non-interactively.** Add `-Confirm:$false -Force` to `Format-Volume`.
  The example expects a user to dismiss a prompt; a CSE runs as SYSTEM with no
  interactive session.
- **Fail loudly.** Wrap the logic in `try`/`catch` and `exit 1` on error. CSE
  success is determined by exit code, and a silent failure defeats the
  `provisionAfterExtensions` gate described below.
- **Decide whether you want Storage Spaces.** The Windows example builds a
  storage pool and virtual disk over the NVMe devices. Partitioning the physical
  disk directly (as in the validation below) keeps the Service Fabric data root
  and shared log on the NVMe device without that abstraction.

Deliver the adapted script as a file through the CSE `fileUris` setting and keep
`commandToExecute` short (for example, run the downloaded `.ps1` file). Do not
embed a full script in `commandToExecute` or `-EncodedCommand`: Windows limits a
command line to approximately 8,191 characters. In deployment validation, an
8,650-character encoded command failed with `The command line is too long`,
while the same script delivered through `fileUris` succeeded.

> [!WARNING]
> The referenced scripts format disks and can erase data. Validate disk selection,
> drive letter or mount point, and behavior with every target SKU and image before
> production deployment.

#### Sequence disk initialization before Service Fabric

Extension order is not implied by the order of entries in the VMSS template.
Name the disk CSE (for example, `InitializeNvmeTempDisk`), then add its exact
extension name to `provisionAfterExtensions` in the **Service Fabric extension's**
`properties`. For a Windows node type, also update `dataPath` to match the
initialized volume:

```json
{
  "properties": {
    "provisionAfterExtensions": [
      "InitializeNvmeTempDisk"
    ],
    "publisher": "Microsoft.Azure.ServiceFabric",
    "type": "ServiceFabricNode",
    "settings": {
      "dataPath": "S:\\SvcFab"
    }
  }
}
```

Merge these fields into the existing Service Fabric extension; do not replace
its other required settings. The dependency name must match the CSE's `name`,
not its `type`. See [Installing dependencies on virtual machine scale set nodes](../Deployment/Installing%20dependencies%20on%20virtual%20machine%20scaleset.md#modify-arm-template-to-add-extension-sequencing-on-service-fabric-extension)
for a complete Service Fabric example and [Use extension sequencing with VM scale sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing)
for the platform behavior.

The dependency is enforced. During deployment validation, a deliberately failed
`InitializeNvmeTempDisk` CSE caused the dependent `ServiceFabricNode` extension
to be marked failed because its prerequisite failed; Service Fabric did not run
against the missing data path.

Extension sequencing controls extension provisioning, not every subsequent OS
boot. Because a temporary NVMe disk can return as a raw device after a stop,
deallocation, maintenance event, automatic recovery, or reimage, arrange for the
idempotent initialization/mount logic to run at startup as well (for example,
with a scheduled task on Windows or a systemd unit on Linux). Services that use
the data path must wait until that startup action completes.

Notes for Option B:

- Use a Generation 2 guest image when required by the selected `_v6` SKU. For
  example, `Standard_D4ads_v6` rejected the Generation 1 Windows Server 2022
  image and deployed successfully with `2022-datacenter-g2`. See
  [Support for Generation 2 VMs on Azure](https://learn.microsoft.com/azure/virtual-machines/generation-2).
- A `_v6` SKU can expose **more than one** local NVMe temp disk. The Windows
  reference script pools all matching disks, and the Linux reference script
  combines them into RAID 0. If that is not intended, select disks
  deterministically rather than assuming a single device.
- The guest OS image must include NVMe driver support (most recent Windows Server
  and Linux images do).

> [!NOTE]
> This configuration was validated with a three-node classic Service Fabric
> cluster using `Standard_D4ads_v6` and `2022-datacenter-g2`. The CSE partitioned
> and formatted the local NVMe temp disk directly (no storage pool or virtual
> disk). On all three nodes, the CSE completed before `ServiceFabricNode`, `S:`
> was an NTFS/GPT volume on `Microsoft NVMe Direct Disk v2`, `FabricDataRoot` was
> `S:\SvcFab`, the startup task was ready, and the cluster reached `Ready`.
> The storage-pool variant in the Windows reference example was not validated in
> this configuration.

### Option C — Use a managed data disk for the data path

Configure the node type to use a **managed data disk** as the data path instead of
the temporary disk. Even in this configuration on a `_v6` / NVMe SKU, the disk must
still be initialized/formatted via a Custom Script Extension (see Option B) — the
platform does not initialize NVMe disks automatically.

## Notes

- Service Fabric (and Reliable Collections) are designed to run on **local disks**.
  Keep the data path on local/managed disk and avoid pointing it at remote/XStore
  backed storage. See [Changing the default DataPath](../Cluster/Changing%20DataPath.md).
- SKUs with **no local temporary storage** are not supported for the SF data path.
  If you must use such a SKU, use a managed data disk (Option C).
- After mitigating with Option A (`_v5`), you can later move to a `_v6` SKU once the
  CSE-based NVMe initialization (Option B) is in place and validated.

## References

- [Deploy a Service Fabric cluster node type with managed data disks (NVMe note)](https://learn.microsoft.com/azure/service-fabric/service-fabric-managed-disk)
- [Configure the Service Fabric managed-cluster data-disk drive letter (`S:` default)](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-modify-node-type#configure-the-service-fabric-data-disk-drive-letter)
- [FAQ for Temp NVMe disks](https://learn.microsoft.com/azure/virtual-machines/enable-nvme-temp-faqs)
- [Use extension sequencing with VM scale sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing)
- [Enable NVMe interface on your VMs and VM scale sets](https://learn.microsoft.com/azure/virtual-machines/enable-nvme-interface)
- [NVMe overview](https://learn.microsoft.com/azure/virtual-machines/nvme-overview)
- [Dadsv6 sizes series](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dadsv6-series)
- [Deploy a managed cluster with stateless node types — temporary disk support](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-stateless-node-type#temporary-disk-support)
- [Changing the default DataPath](../Cluster/Changing%20DataPath.md)
