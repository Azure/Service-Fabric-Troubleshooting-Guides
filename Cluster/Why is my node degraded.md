# Degraded Node Detected

You might see a node health warning being reported in SFX indicating DegradedNodeDetected. If that is the case, you can follow this article. 
> A degraded node can potentially cause routing/broadcast to fail and therefore cause problems in the overlying systems.  
This is an indicator that the node is not working properly, resources might not be available and action should be taken.

## Triage

### Is the report stale?
The 'DegradedNodeDetected' health report is emitted every 30 seconds. You can find it in the health evaluations segment of SFX, clicking on the node that is reporting the warning. If you see the reporting time (source UTC) has not changed in a couple minutes, the issue is not happening anymore and the report will go away once it expires (30 minutes).

### The issue is ongoing

The report is periodically emitted. 

- **Network failed:** Indicates the node is unable to establish new connections within itself. Connections made before this point might be able to work, but no new connection can be made.
- **Memory failed:** Indicates the node is unable to allocate 1MB of memory. This is a system failure, node should be restarted.
- **Disk failed:** This indicates the node is unable to read/write into the disk. This could be caused by a faulty disk, an OS problem, the node is unable to flush its data or could also be a side effect of the node consumming too much memory. This problem can make the node bugcheck when the probe goes unresponsive for more than 15 minutes. This can also make the node fail to open the reliability subsystem; if that is the case, you will see a health report indicating so. 
## Diagnose
- The warning should include a status code to investigate. Use this status code to investigate what can cause the reported condition.
- You might need to RDP into the node in order to check what is happening. You may find that the node is unresponsive and the RDP session can't be established. If that is the case, [try restarting the node](#Restart-the-Service-Fabric-Node )

### Network probe failed
Go to [winsock error codes](https://learn.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2) and see what can trigger the reported error.
You might have found `0x80072747: WSAENOBUFS`. If that is the case, [check for port exhaustion;](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/tcp-ip-port-exhaustion-troubleshooting)
If you happen to find a process responsible for this condition, [restarting the process](#stop-the-rogue-process) can alleviate port exhaustion since that will free up ports allocated by the process.

### Memory probe failed
The node might not have enough memory to perform the requested operation. There might be a leaking process, or the node could be overloaded. 
If you have access to the node, investigate what is causing the memory exhaustion problem inside the node. Open Windows Task Manager and check the memory usage; you might find a process using excessive memory, or multiple spawn processes; 
If that is the case, you would need to [stop the process.](#stop-the-rogue-process) <br/>
If the node is not responding or there is no apparent cause for this failure to happen, [try restarting the node.](#restart-the-node)

### Disk Probe
> This is reported from the root disk where fabric bits are installed.

This problem gets automatically mitigated after 15 minutes of solid failures. If the node doesn't restart and you keep seeing this error, it could mean that the problem is transient and it is possible that the node has a bad disk or there might be an ongoing issue causing disk unavailability. <br/>
Open the Windows Event Viewer. Inside Windows Logs/System You might be able to see some warnings/errors where the disk is the source. Use [chkdsk](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/chkdsk?tabs=event-viewer) to check and try to repair the disk.<br/> 
If the disk is healthy, there could be a problem with the system and [restarting the node](#restart-the-node) could help to mitigate the issue.

# Mitigations

## Stop the rogue process
If the reason for the failure is a rogue process whose behavior is impacting fabric, stop the process. You can do it from the task manager by right clicking on the process and then click on **End task**. If you are using the command line for diagnose, you can also run
`taskkill /f /pid <rogue-process-pid>`
> If you can't see the process id in task manager, right click in one of the task manager column headers and select the PID option.

## Restart the Service Fabric Node 
**WARNING:** Make sure restarting the node won't cause problems to Service Fabric. If the node to restart is a seed node, make sure the remaining count of alive seed nodes is **greater** than the total count of seed nodes divided by two. 
- First, Try to restart the node by using Restart-ServiceFabricNode; however, this command could fail to restart the node since it is already in a degraded state. If this approach does not alleviate the issue, you will need to manually restart the machine; for Windows, run `shutdown /r /t 0`. For Linux, run `shutdown -r now`.
- RDP into the node and manually restart it.
- If RDP is not an option, you might need to manually restart the node using the compute provider, such as restarting the node from the Azure Portal.


