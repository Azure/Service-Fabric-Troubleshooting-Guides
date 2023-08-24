# Unresponsive Neighbor Detected
You might see a cluster health warning being reported in SFX/Events indicating 'UnresponsiveNeighborDetected'. If that is the case, you can follow this article. 
> This warning will be triggered in case the lease and/or fabric ports are not reachable from a neighbor node. Make sure that the reported node isn't in warning state due to another report. If that is the case, the health report could indicate an issue that might be related to this failure. 

## Diagnose:

1. RDP to the node reported as the destination
> If the node is not responding to the RDP session, check why the host is not responsive. A VM restart is suggested.
2. Once you have connected to the VM, Check that Fabric is working by local ping. Check the manifest and use the port defined as clusterConnectionEndpointPort <br/>  
run `Test-NetConnection localhost -Port <port-number>` 

3. Now, check that Service Fabric Lease driver is working by local ping. Check the manifest and use the port defined as leaseDriverEndpointPort <br/>  
run `Test-NetConnection localhost -Port <port-number>` 
4. **If both local pings succeed**, RDP into the node that reported the event. Run the same steps as in 2 and 3, but replace localhost with the IP address of the node reported as destination. 
you might discover the node is not able to reach the remote end. Check for any firewall policy or any network rule that might prevent the connection to succeed. If the policies look good, you will need to investigate why these nodes can't talk to each other.
5. **If one/both of the local pings failed**, check the [mitigations](#mitigations) section.
   
## Mitigations

### If the ping to clusterConnectionEndpointPort failed, stop Fabric.exe process
Go to the Windows Task Manager, right click on Fabric.exe and click on end task. You can also stop the process using [taskkill](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/taskkill).<br/> 
`taskkill /f /pid <rogue-process-pid>`


### If the ping to leaseDriverEndpointPort failed, Restart the node 
**WARNING:** Make sure restarting the Service Fabric Node won't cause problems to Service Fabric. If the node to restart is a seed node, make sure the remaining count of alive seed nodes is **greater** than the total count of seed nodes divided by two. 
- Try to restart the node by using Restart-ServiceFabricNode; however, this command could fail to restart the node since it is already in a degraded state.
- RDP into the node and manually restart it.
- If RDP is not an option, you might need to manually restart the node using the compute provider, such as restarting the node from the Azure Portal.





