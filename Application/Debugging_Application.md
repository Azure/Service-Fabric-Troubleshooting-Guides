# Debug Application issues for services deployed to an Azure Service Fabric Cluster

- Install AZ Cli from https://aka.ms/installazurecliwindowsx64 
- Publish the debug build of your application to the cluster
- Az account set --subscription <subscriptionid>
- Execute the following 2 commands ```(Get the values for <LoadBalancerName>, <vmssname>, <resource-group-name> from the portal)```

# Create an inbound-nat-pool and assign front end port range and backend ports.
```az network lb inbound-nat-pool create -g <resource-group-name> --lb-name <LoadBalancerName> -n VSDebugPool --protocol Tcp --frontend-port-range-start 40026 --frontend-port-range-end 40126 --backend-port 4026 ```

If successful, should return

{ "backendPort": 4026, "enableFloatingIP": false, "enableTcpReset": false, "etag": "W/"467fe3f7-8ed2-4e94-9da3-18068a6b45c8"", "frontendIPConfiguration": { "id": "/subscriptions/<subId>/resourceGroups/djbsfcluster-rg/providers/Microsoft.Network/loadBalancers/LB-djbsfcluster-7kfjjnciu/frontendIPConfigurations/LoadBalancerIPConfig", "resourceGroup": "djbsfcluster-rg" }, "frontendPortRangeEnd": 40126, "frontendPortRangeStart": 40026, "id": "/subscriptions/<subId>/resourceGroups/djbsfcluster-rg/providers/Microsoft.Network/loadBalancers/LB-djbsfcluster-7kfjjnciu/inboundNatPools/VSDebugPool", "idleTimeoutInMinutes": 4, "name": "VSDebugPool", "protocol": "Tcp", "provisioningState": "Succeeded", "resourceGroup": "djbsfcluster-rg", "type": "Microsoft.Network/loadBalancers/inboundNatPools" }

# Adds the vmss instances to the inbound-nat-pool created above
```az vmss update -g <resource-group-name> -n <vmssname> --add virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].ipConfigurations[0].loadBalancerInboundNatPools id=<id from above>```

- Log into the portal, then Remote into an instance (node) on VMSS of the SF cluster either using RDP (3389) or Bastion.
- Install the Remote Tools from https://aka.ms/vs/17/release/RemoteTools.amd64ret.enu.exe 
- Launch “Remote Debugger” from Windows Search bar (this should launch msvsmon.exe) after a dialog asking to configure remote debugging
- Get the IP address from the Load Balancer Frontend IP configuration in the portal
- Attach to Process in Visual Studio Debug menu, specify “Remote (Windows)” as connection type and enter <ipaddress>:40026 for the connection target.

You should get a prompt for username/password that was used when setting up the cluster. Same account that you log into the VM with.

NOTE: MSVSMon.exe can be started with /noauth and can be found at "C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger\x64". If doing that, choose "Remote (Windows - No Authentication) in Visual studio Connection Type.