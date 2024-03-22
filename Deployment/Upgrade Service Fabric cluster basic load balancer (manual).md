# Upgrade from Basic to Standard SKU on Azure Load Balancer for Azure Service Fabric clusters manual process with no down time 

This document outlines the manual process to upgrade from Basic to Standard SKU with no down time, as part of the Load Balancer Deprecation Migration guide detailed [here](./Upgrade%20Service%20Fabric%20cluster%20basic%20load%20balancer.md).

To upgrade Azure Load Balancers on Basic SKU together with Azure Service Fabric (ASF) cluster with no downtime requires the creation of a new Azure Virtual Machine Scale Set (VMSS),  Node Type configuration in ASF, Azure Load Balancer with Standard SKU, and Azure IP Address with Standard SKU. After the new Node Type is added to the cluster configuration, you need to configure your load balancer depending on your specific scenario as shown in the decision diagram below. Lastly, applications are migrated to the new node type, and the old node type with associated old Azure Load Balancer and Azure IP Address on Basic SK are deactivated and removed. This process takes multiple hours to complete and is documented in [Scale up a Service Fabric cluster primary node type](https://learn.microsoft.com/azure/service-fabric/service-fabric-scale-up-primary-node-type) and [Scale up a Service Fabric cluster non-primary node type](https://learn.microsoft.com/azure/service-fabric/service-fabric-scale-up-non-primary-node-type).

### Things to consider

- Azure Load Balancer on Standard SKU (LBS) restrict traffic by default so you need to allow traffic through Azure Network Security Group (NSG). If you do not have an NSG make sure you add one to your subnet before the migration with all necessary rules. Read more in [Service Fabric Networking Best Practices](https://learn.microsoft.com/azure/service-fabric/service-fabric-best-practices-networking#network-security-rules).
- LBS requires a Azure IP Address on Standard SKU. Take into account that a public IP address will change as part of this migration. Preserving the IP address in this case is not possible.
- Read more about the SKU of Azure Load Balancer including [comparison of Basic to Standard](https://learn.microsoft.com/azure/load-balancer/skus#skus).
- Azure Load Balancer on Standard SKU configured as internal-only (ILB) don't have outbound connectivity by design. If you are using an internal-only configuration, make sure you plan ahead to have an outbound configuration when you migrate to standard ILB (i.e. using internal + public LB or NAT gateway). Read more about [outbound connectivity](https://learn.microsoft.com/azure/load-balancer/outbound-rules#outbound-rules-scenarios).
- If you use the Add-AzServiceFabricNodeType PowerShell module the new LB will always get created with Basic SKU. You would need to use the Start-AzBasicLoadBalancerUpgrade module to upgrade the new LB to Standard SKU and make the necessary configurations for your new load balancer as stated in this guide.
- Changing the DNS name to the new Load Balancer will cause a few seconds of connection loss to SFX.

The following table outlines the process and effort required for each LB scenario.

| Scenario | Effort | Additional requirements | Process | 
| --- | --- | --- | --- |
| Public Load Balancer | Low | NSG | [Basic Migration](#basic-migration) |
| Public and Internal Load Balancer | Medium | NSG | [Internal and external migration](#internal-and-external-migration) | 
| Internal-only Load Balancer | High | outbound connectivity solution (NAT gateway) | [Internal-only migration](#internal-only-migration) | 

The following diagram details the migration path required for each load balancer scenario. 

<img width="698" alt="LBscenarios_flowcharts" src="https://github.com/jagilber/Service-Fabric-Troubleshooting-Guides/assets/50681801/9ac77241-0035-42ec-b718-6813cc3f0b35">

### Basic migration

When you have a LB with Basic SKU you only need to make sure that you have the necessary rules and probes set up in your new LB before migrating. Make sure that you migrate any additional network configuration to the new IP address as needed.

### Internal and external migration

When you have a combination of internal and external LB you should use the public LB for the management endpoint and outbound connectivity of the cluster. The private LB should be used for any internal traffic. You can read more about the scenario [internal and external load balancer](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking#internal-and-external-load-balancer).

### Internal-only migration

For internal-only migration you need to consider an outbound connectivity solution. We recommend using a combination of internal and external load balancers as mentioned above, or using a NAT gateway for outbound connectivity. This document specifies the process you should take when adding a NAT gateway. You can follow the [tutorial for setting up NAT gateway with ILB on Standard SKU](https://learn.microsoft.com/azure/nat-gateway/tutorial-nat-gateway-load-balancer-internal-portal).

You need to have a public load balancer for the migration of the workload to the new node type. If not, the new nodes will not be able to get added to the cluster since it requires outbound connectivity, and the NAT gateway cannot be added to the subnet if there are any Basic SKU resources. Take into account that this means you will have a public IP exposed temporarily during the migration. After this has been completed, change the load balancer from public to private following these steps:

> [!IMPORTANT]
> If you create your load balancer in a region that supports [Azure Availability Zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-service-support), make sure you specify a zone, instead of selecting "no zone" in the Availability Zone setting of the frontend IP configuration. Otherwise, a random zone will be selected and the update could fail. Read more about [non-zonal load balancer](https://learn.microsoft.com/en-us/azure/reliability/reliability-load-balancer?tabs=graph#non-zonal-load-balancer).

1. Go to [resources.azure.com](https://resources.azure.com), navigate to your load balancer and select 'Edit' at the top of the page.
2. Remove the publicIPAddress parameter in the frontendIpConfiguration section and replace it with the following:

    ```json
    "privateIPAddress": "10.0.0.250",
    "subnet": {
        "id": "<subnet resource id>"
        },
    ```

    Private IP 10.0.0.250 was used as an example but you can set this value as needed. Make sure the privateIPAllocationMethod is set to 'Static'.

3. Click PUT at the top of the page and wait for the update to complete.
After this, you can remove the public IP resource if it's not being used.

### Additional considerations

- This documentation takes into account the scenarios specified in [Service Fabric Networking Patterns](https://learn.microsoft.com/azure/service-fabric/service-fabric-patterns-networking). If you have a different configuration for your load balancers or if you encounter any issues when following this process, please engage the Service Fabric support for further assistance.
