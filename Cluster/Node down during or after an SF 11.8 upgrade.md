# Node down during or after an SF 11.8 upgrade

Use this TSG for a Windows Service Fabric cluster running or upgrading to `11.8.121.1`.

## Symptoms

- A cluster upgrade to SF 11.8 fails to roll forward and automatically rolls back to SF 11.7.
- Applications or services become unhealthy on nodes as those nodes move to SF 11.8.
- A new or rebuilt SF 11.8 cluster remains in `Deploying`, with VM scale set node types remaining in `Updating`.
- A previously healthy cluster develops unhealthy nodes after a deployment, maintenance operation, or node restart.
- A node is in the `Down` state and its corresponding VM restarts on a regular cadence.

## Cause

`FabricHost.exe` loads the centrally installed Visual C++ runtime from `C:\Windows\System32` when one is present. If no central runtime is present, FabricHost uses the runtime DLLs installed locally with Service Fabric. A centrally installed runtime older than `14.38.33135.0` is incompatible with the affected native components in SF 11.8 and can cause FabricHost to fail while `libprotobuf.dll` initializes.

This is not an SF package defect. It is caused by a centrally installed Visual C++ Redistributable from a runtime generation earlier than 14.38. Production failures loaded `14.28.29334.0` from System32, and controlled testing reproduced the failure with `14.36.32532.0`. Runtime `14.38.33135.0` is the minimum version confirmed compatible with this scenario.

## Prerequisites

- Administrator access and an elevated 64-bit PowerShell session on an affected node.
- Permission to update the cluster resource through its owning deployment mechanism.
- Optional: Watson access to correlate existing dumps.

## Confirm that this TSG applies

Confirm all of the following:

1. The node is running or attempting to run SF `11.8.121.1`.
1. Event 1000 or a dump identifies:
   - Faulting application: `FabricHost.exe`
   - Faulting module: `MSVCP140.dll`
   - Faulting module path: `C:\Windows\System32\MSVCP140.dll`
   - Exception code: `0xc0000005`
1. The System32 Visual C++ runtime is older than `14.38.33135.0`. Confirmed examples include production runtime `14.28.29334.0` and controlled reproduction runtime `14.36.32532.0`.

The following are supporting indicators:

- Bootstrap logs contain `FabricHostSvc is not running after executing FabricInstallerSvc`, `Running FabricInstallerSvc didn't bring up FabricHost`, or `StartFabric failed`.
- Watson reports `ACCESS_VIOLATION_c0000005_libprotobuf.dll!google::protobuf::internal::OnShutdownRun`.

Run this script from an elevated 64-bit PowerShell session. It returns matching events, the installed Visual C++ Redistributable packages, System32 runtime versions, and the modules loaded by FabricHost when the process remains running.

```powershell
Write-Host 'Matching Application events'
Get-WinEvent -FilterHashtable @{
    LogName   = 'Application'
    Id        = 1000
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Message -match 'FabricHost\.exe' -and
        $_.Message -match 'MSVCP140\.dll' -and
        $_.Message -match 'C:\\Windows\\System32\\MSVCP140\.dll'
    } |
    Select-Object TimeCreated, Id, Message

Write-Host 'Installed x64 Visual C++ Redistributable packages'
Get-ItemProperty `
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -match 'Microsoft Visual C\+\+' -and
        $_.DisplayName -match 'Redistributable' -and
        $_.DisplayName -match '\(x64\)|\bx64\b'
    } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName, DisplayVersion -Unique |
    Format-Table -AutoSize

$runtimeNames = @(
    'MSVCP140.dll',
    'VCRUNTIME140.dll',
    'VCRUNTIME140_1.dll'
)

Write-Host 'System32 Visual C++ runtime'
$runtimeNames | ForEach-Object {
    $path = Join-Path $env:SystemRoot "System32\$_"
    if (Test-Path -LiteralPath $path) {
        $file = Get-Item -LiteralPath $path
        [pscustomobject]@{
            Name           = $file.Name
            Path           = $file.FullName
            FileVersion    = $file.VersionInfo.FileVersion
            ProductVersion = $file.VersionInfo.ProductVersion
        }
    }
} | Format-Table -AutoSize

$fabricHost = Get-Process -Name FabricHost -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($fabricHost) {
    Write-Host 'Modules loaded by FabricHost'
    $fabricHost.Modules |
        Where-Object {
            $_.ModuleName -in ($runtimeNames + 'libprotobuf.dll')
        } |
        Select-Object ModuleName, FileName,
            @{n='FileVersion';e={$_.FileVersionInfo.FileVersion}} |
        Format-Table -AutoSize
} else {
    Write-Warning 'FabricHost is not running; loaded modules cannot be inspected.'
}
```

If the event signature matches and the System32 runtime is from any generation earlier than `14.38.33135.0`, proceed to mitigation. The permanent remediation target is the complete Microsoft x64 Visual C++ Redistributable package at version `14.44.35211.0` or later.

## Mitigation

### Immediate mitigation: Pin the cluster to SF 11.7

1. Update the `Microsoft.ServiceFabric/clusters` resource in the ARM template, Bicep file, or other deployment source that owns the cluster:

   ```json
   {
     "properties": {
       "upgradeMode": "Manual",
       "clusterCodeVersion": "11.7.157.1"
     }
   }
   ```

1. Deploy the updated cluster resource. Do not make only a temporary portal change if a deployment pipeline can overwrite it.
1. Confirm that every node type reports `11.7.157.1`, VM scale set provisioning stabilizes, and the cluster reaches `Ready`.

> [!NOTE]
> Pinning to SF 11.7 stops the immediate crash and restart cycle but does not correct the outdated runtime. Keep the cluster pinned to SF `11.7.157.1`; do not upgrade to SF 11.8 or later until the permanent mitigation below is complete.

### Permanent mitigation: Update the centrally installed Redistributable

1. Identify the deployment pipeline, base image, extension, or artifact that centrally installs the Visual C++ runtime.
1. Update it to deploy the complete Microsoft x64 Visual C++ Redistributable (`vc_redist.x64`) package at version `14.44.35211.0` or later before Service Fabric starts.
1. Do not service or replace the runtime DLLs individually.
1. Rerun the confirmation script and verify that the installed `vc_redist.x64` package is `14.44.35211.0` or later and FabricHost loads the updated System32 runtime.
1. Upgrade to SF 11.8 or later only after the package and loaded-module checks pass.

## Validation

Confirm all of the following after mitigation:

1. All nodes are `Up`.
1. The corresponding VMs no longer restart on a regular cadence.
1. The centrally installed Microsoft x64 Visual C++ Redistributable package is version `14.44.35211.0` or later.
1. `FabricHost.exe` remains running.
1. No new matching event 1000 entries or Watson dumps appear.
1. The cluster and its applications are healthy.


## Appendix: Representative crash stack

The exact offsets may differ by dump. The characteristic sequence is:

```text
msvcp140!mtx_do_lock
std::_Mutex_base::lock
libprotobuf!google::protobuf::internal::WrappedMutex::Lock
libprotobuf!google::protobuf::internal::Mutex::Lock
libprotobuf!google::protobuf::internal::OnShutdownRun
libprotobuf!protobuf default-instance initialization
libprotobuf!DLL process attach initialization
ntdll!LdrpCallInitRoutine
ntdll!LdrpInitializeNode
ntdll!LdrInitializeThunk
```
