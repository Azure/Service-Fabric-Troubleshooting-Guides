# Cluster create or runtime upgrade fails — "FabricHostSvc was not installed by FabricInstallerSvc / FabricSetup may have failed"

## Problem

- Creating a Service Fabric cluster, or performing a Service Fabric runtime upgrade, fails on **every** node almost immediately.
- The failure is independent of the Service Fabric runtime version being deployed and is not related to the cluster certificate, network connectivity, or cluster configuration.
- The missing `FabricHostSvc` service is a downstream symptom. The actual fault is the node operating system, not the cluster — so this can occur on any deployment type whose node OS is missing the required Windows update (see **Applies to** below).

## Quick triage

Use this guide when the failure has this shape:

- `FabricSetup.exe` starts and exits in well under a second.
- `FabricInstallerService` then reports `0x80070424` (`ERROR_SERVICE_DOES_NOT_EXIST`) because `FabricHostSvc` was never registered.
- The same failure happens on every node that uses the same OS image or patch level.
- There is no `FabricSetup.exe` crash event in Windows Error Reporting or Application Error events.

Do **not** treat this as a normal missing-service repair. Manually creating or restarting `FabricHostSvc`, retrying the Service Fabric extension, or switching to another affected runtime version will not fix the node. The node OS must be patched so `FabricSetup.exe` can enable RedirectionGuard successfully.

## Applies to

`FabricSetup.exe` is part of the Service Fabric **runtime package** that is laid down on every node, so this issue is **not** specific to any one deployment type. It can occur for any cluster type when the node operating system lacks the cumulative update that adds RedirectionGuard support:

| Deployment type | Who patches the node OS | Likelihood |
| --- | --- | --- |
| On-premises / customer-managed Windows nodes | Customer, manually | **Highest** — stale OS images are common |
| Azure classic clusters (SFRP on customer-managed VMSS) | Customer — the marketplace image *version* is pinned at deploy time; [automatic OS image upgrade](../Deployment/How%20to%20Configure%20Service%20Fabric%20Cluster%20Automatic%20OS%20Image%20Upgrade.md) is opt-in | **Possible** — long-running VMSS on an old image version, a stale custom image, or auto OS image upgrade disabled |
| Azure Service Fabric managed clusters | Platform manages the image / OS patching | **Lowest** — but not zero if the OS patch level lags the runtime |

> Azure Marketplace Windows Server images are republished regularly with current cumulative updates, so newly provisioned marketplace-based nodes usually already include RedirectionGuard support. However, a deployed VMSS keeps using the image version it was created with until [automatic OS image upgrade](../Deployment/How%20to%20Configure%20Service%20Fabric%20Cluster%20Automatic%20OS%20Image%20Upgrade.md) is enabled or the image reference is updated. Custom-image and patch-frozen environments are exposed regardless of where they run.

## Affected Service Fabric versions

The RedirectionGuard enablement is part of the Service Fabric runtime, so the affected boundary is by **runtime version**, not deployment type:

| Service Fabric runtime | RedirectionGuard enabled in `FabricSetup`? |
| --- | --- |
| **10.1 CU7 (10.1.2846.9590) and later 10.1 CUs** | Yes |
| **11.x (all releases)** | Yes |
| **12.0 and later** | Yes |
| 10.1 CU6 and earlier, 10.0, 9.x, 8.x | No — not affected |

Because every runtime at or above 10.1 CU7 performs the same mitigation call, switching to a different in-support runtime version does **not** work around the issue — the node OS must be patched.

## Symptoms

- The deployment fails for all nodes with an error similar to the following:

    ```text
    FabricHostSvc was not installed by FabricInstallerSvc on machine <node-ip>. FabricSetup may have failed.
    ... ---> System.Fabric.FabricServiceNotFoundException: FabricHostSvc was not installed by FabricInstallerSvc on machine <node-ip>. FabricSetup may have failed.
    ```

- In the `FabricInstallerService` trace, `FabricSetup.exe` is launched and the installer fails to find `FabricHostSvc` within **tens of milliseconds**, then rolls back:

    ```text
    Calling upgrade entry point
    Upgrade executing: FabricSetup.exe /operation:Install ...
    CreateProcess Successful ProcessId:<pid>
    starting fabric host service
    Error 0x80070424 while waiting fabric host service to start. Rolling back..
    Rollback cannot be performed since the current installation is not present or invalid
    Upgrade finished with error FABRIC_E_UPGRADE_FAILED
    ```

  - `0x80070424` is `ERROR_SERVICE_DOES_NOT_EXIST` — `FabricHostSvc` was never registered, because `FabricSetup.exe` exited before creating it.

- When `FabricSetup.exe` is run interactively, it prints:

    ```text
    Failed to configure execution environment.
    ```

  and exits with a non-zero exit code without installing `FabricHostSvc`.

- Distinguishing characteristics that point to this issue rather than certificate, network, or configuration problems:
  - The failure is **instantaneous** (FabricSetup exits in well under a second).
  - It happens on **all** nodes identically.
  - It is **version‑independent** across affected runtimes — different runtime packages fail the same way.
  - There is **no** Windows Error Reporting / Application Error (Event ID 1000) crash for `FabricSetup.exe` — it returns a deliberate failure exit code, it does not crash.
  - `FabricHostSvc` never appears in the System event log Service Control Manager events (no 7045 install / 7036 running).

## Cause

Recent Service Fabric runtimes enable the Windows **RedirectionGuard** process mitigation in `FabricSetup.exe` as part of the security hardening for [CVE-2025-59189](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-59189). Early in startup, `FabricSetup.exe` calls:

```cpp
PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY ReparsePointPolicy = {0};
ReparsePointPolicy.EnforceRedirectionTrust = 1;
SetProcessMitigationPolicy(ProcessRedirectionTrustPolicy, &ReparsePointPolicy, sizeof(ReparsePointPolicy));
```

RedirectionGuard (`PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY` / `ProcessRedirectionTrustPolicy`) is an opt-in Windows mitigation that prevents a privileged process from following untrusted, non-admin-created junctions / reparse points. See the Microsoft Security Response Center blog [RedirectionGuard: Mitigating unsafe junction traversal in Windows](https://www.microsoft.com/en-us/msrc/blog/2025/06/redirectionguard-mitigating-unsafe-junction-traversal-in-windows/).

RedirectionGuard support was delivered to Windows through cumulative servicing updates. On a node whose operating system is **down‑level or missing the cumulative update that adds RedirectionGuard support**, the `SetProcessMitigationPolicy(ProcessRedirectionTrustPolicy, ...)` call fails. When that call fails, `FabricSetup.exe` reports `Failed to configure execution environment.` and exits **before** it registers `FabricHostSvc`. `FabricInstallerService` then cannot start `FabricHostSvc`, receives `0x80070424` (`ERROR_SERVICE_DOES_NOT_EXIST`), and rolls the deployment back with `FABRIC_E_UPGRADE_FAILED`.

This is why the failure is instantaneous, identical on every node, and independent of the runtime version: every node shares the same un‑patched OS image, and every affected runtime performs the same mitigation call at startup. Because `FabricSetup.exe` ships in the runtime package, the same failure can occur for any Service Fabric cluster type (on-premises, Azure classic / SFRP, or managed) — wherever the node OS is missing the RedirectionGuard update.

## How to confirm

1. **Confirm the trace signature in the collected logs.** In the `FabricInstallerService` trace, `FabricSetup.exe` is launched and the installer fails to find `FabricHostSvc` within tens of milliseconds, then rolls back with `0x80070424` (`ERROR_SERVICE_DOES_NOT_EXIST`):

    ```text
    Upgrade executing: FabricSetup.exe /operation:Install ...
    CreateProcess Successful ProcessId:<pid>
    starting fabric host service
    Error 0x80070424 while waiting fabric host service to start. Rolling back..
    Upgrade finished with error FABRIC_E_UPGRADE_FAILED
    ```

   Note the negative signals that distinguish this from a crash or a certificate/network problem: `FabricSetup.exe` writes **nothing** to the Windows Application or System event log, there is **no** Windows Error Reporting / Application Error (Event ID 1000) for `FabricSetup.exe`, and `FabricHostSvc` never appears in the System log Service Control Manager events (no 7045 install / 7036 running).

2. **Check the OS patch level on the nodes.** RedirectionGuard requires a current Windows cumulative update. Read the authoritative build + revision (`UBR`) from the registry and compare it against a patched reference machine.

    ```powershell
    # OS build and revision, e.g. 17763.737
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    "$($cv.CurrentBuild).$($cv.UBR)"

    # Installed cumulative updates (look for a stale / old most-recent update)
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
    ```

   A node whose most recent cumulative update is months or years old is the classic signature.

3. **Run FabricSetup interactively** from the extracted package on a failing node and observe the message. Run this only on a node that is already failed or isolated for troubleshooting, because a patched node may proceed with installation work instead of failing immediately.

    ```powershell
    .\FabricSetup.exe /operation:Install
    # => Failed to configure execution environment.
    ```

4. **Confirm `FabricHostSvc` was never created:**

    ```powershell
    Get-Service FabricHostSvc   # not found
    ```

5. *(Optional)* Verify whether RedirectionGuard is actually active on a node using James Forshaw's `NtObjectManager` PowerShell module, as described in the [RedirectionGuard blog](https://www.microsoft.com/en-us/msrc/blog/2025/06/redirectionguard-mitigating-unsafe-junction-traversal-in-windows/). `FabricSetup.exe` itself is too short‑lived to capture by PID on a failing node, so inspect a long‑running Fabric process on a **patched** node (where the cluster came up) to confirm the mitigation is available and enabled:

    ```powershell
    # On a patched node with a running cluster
    Get-NtProcessMitigations -Name FabricHost.exe
    # inspect the RedirectionTrust policy in the output
    ```

## Mitigation / Resolution

- **Install the latest Windows cumulative updates on every node**, then reboot, so the operating system includes RedirectionGuard (`ProcessRedirectionTrustPolicy`) support. After patching, re‑run the cluster create / runtime upgrade.
- Ensure all nodes are patched to the **same** current level — a single un‑patched node will fail the deployment.
- For custom-image deployments, update the base image so newly provisioned nodes are patched before they join.
- For Azure clusters, deploy from a current marketplace image version and consider enabling [automatic OS image upgrade](../Deployment/How%20to%20Configure%20Service%20Fabric%20Cluster%20Automatic%20OS%20Image%20Upgrade.md) (or [managed cluster automatic OS image upgrade](../Deployment/How%20to%20Configure%20Service%20Fabric%20Managed%20Cluster%20Automatic%20OS%20Image%20Upgrade.md)) so nodes stay patched.

## References

### In this repo

- [How to Configure Service Fabric Cluster Automatic OS Image Upgrade](../Deployment/How%20to%20Configure%20Service%20Fabric%20Cluster%20Automatic%20OS%20Image%20Upgrade.md)
- [How to Configure Service Fabric Managed Cluster Automatic OS Image Upgrade](../Deployment/How%20to%20Configure%20Service%20Fabric%20Managed%20Cluster%20Automatic%20OS%20Image%20Upgrade.md)
- [Troubleshooting failed Fabric Upgrade](../Cluster/Troubleshooting%20failed%20Fabric%20Upgrade.md)
- [SF collect node info](../Cluster/SF%20collect%20node%20info.md)

### External

- [RedirectionGuard: Mitigating unsafe junction traversal in Windows (MSRC blog)](https://www.microsoft.com/en-us/msrc/blog/2025/06/redirectionguard-mitigating-unsafe-junction-traversal-in-windows/)
- [PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY structure (Win32)](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-process-mitigation-redirection-trust-policy)
- [SetProcessMitigationPolicy function (Win32)](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setprocessmitigationpolicy)
- [CVE-2025-59189](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-59189)
- [Patch the Windows operating system in your Service Fabric cluster](https://learn.microsoft.com/azure/service-fabric/how-to-patch-cluster-nodes-windows)
