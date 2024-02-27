# Breaking change in .NET 5+ causes Reliable Collections with string keys to crash

## Symptoms
- **Either**:
  - On .NET 5+ and attempting to rollout a VM OS image upgrade from Server 2019 to Server 2022+
  - Attempting to rollout an application upgrade which updates the .NET version to 5+.
- Using Reliable Collections with a string key or a custom key containing a string member
- OS or Application UD walk gets blocked due to safety checks. A message on the upgrade page in SFX such as this would be present:
  ```
  Status: Failed
  Error:    
  Code: RepairTaskTimeout
  Message: RepairTask SFRP-f0e20000-f293-49d0-a78e-d40ea157ed94-UD-3 not approved within expected time: 00:35:00 (04/15/2023 00:13:03). Node deactivation statuses: vm_3: EnsurePartitionQuorum for partition 44afb318-f11c-4235-adaf-551144523abc.
  ```
- All Replicas for an impacted partition that have applied the update crash repeatedly while trying to open. Search for crash dumps, windows events, or the customers configured telemetry for evidence of process crashes matching the following message and stack trace:
  ```
  Application: MySFService.exe
  CoreCLR Version: 6.0.1523.11507
  .NET Version: 6.0.15
  Description: The application requested process termination through System.Environment.FailFast(string message).
  Message: Cannot add an item that already exist. Txn: 133258988496518634 CommitLSN: 985327 CheckpointLSN: 983927 key: 4086459251731459679 RecordKind: InsertedVersion
  Description: The process was terminated due to an unhandled exception.System.Exception:    at System.Environment.get_StackTrace()
    at System.Fabric.Data.Common.Diagnostics.AssertHelper(TraceId sourceTypeName, String format, Object[] args)
    at System.Fabric.Store.TStore`5.OnApplyAdd(TransactionBase txn, MetadataOperationData metadataOperationData, RedoUndoOperationData operationRedoUndo, Boolean isIdempotent, String applyType)
    at System.Fabric.Store.TStore`5.OnRecoveryApplyAsync(Int64 sequenceNumber, TransactionBase replicatorTransaction, OperationData metadata, OperationData operationData)
  ```
- Depending on upgrade policy, the upgrade may rollback due to the unhealthy replicas, with the impacted services recovering. However, retrying the upgrade will not resolve the issue without application of the mitigation.

## Cause

.NET 5+ introduced a [breaking change](https://learn.microsoft.com/en-us/dotnet/standard/base-types/string-comparison-net-5-plus) which changed the default library used for string globalization from NLS to ICU. If ICU is not present on the machine, it falls back to using NLS.

For built-in types such as string, Reliable Collections uses the .NET provided default for string comparison.  Since this changes string ordering, the state already persisted using the previous default library becomes inconsistent when opened after the breaking change.

Windows Server 2019 does not ship with the `ICU.dll` so customers running .NET 5+ on Server 2019 persisted state using NLS instead of ICU. As a result, when an application is migrated to Server 2022+ where the DLL is present, the application will attempt to parse the persisted state using the ICU library and crash due to the inconsistency in ordering and equality.

## Mitigation
If an upgrade is in progress or stuck due to this issue, first rollback the upgrade.

To resolve the issue, the application must be configured to make .NET use the old default string localization library (NLS) which is consistent with the persisted state.

This is done by setting the `System.Globalization.UseNls` [runtime configuration](https://learn.microsoft.com/en-us/dotnet/core/runtime-config/globalization#nls) to `true`.

Examples on how to add this runtime configuration setting to your services project file or runtimeconfig.json can be found [here](https://learn.microsoft.com/en-us/dotnet/core/runtime-config/globalization#examples).

Rollout an upgrade for the impacted service(s) with the setting change. After it succeeds, retry the application or OS image upgrade operation.

## Resolution

Currently, services which have hit this issue must keep this setting in their runtime configuration for the lifetime of the persisted state of this service. New deployments without existing data do not need the setting and can use the new .NET default for string localization, but currently there are no workarounds to migrate data persisted with the old default to the new one.
