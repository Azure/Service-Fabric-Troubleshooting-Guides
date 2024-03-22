# Upgrade from Basic to Standard SKU on Azure Load Balancer for Azure Service Fabric clusters

## Abstract

Azure Load Balancers with Basic SKU will be retired on September 30th, 2025. To ensure that your Azure Load Balancer continues to function properly, we recommend that you migrate to a Azure Load Balancer with Standard SKU before the deprecation date. After this date, Microsoft cannot guarantee the functionality of any existing Azure Load Balancer with Basic SKU. Read more in the [official retirement announcement](https://azure.microsoft.com/updates/azure-basic-load-balancer-will-be-retired-on-30-september-2025-upgrade-to-standard-load-balancer/). If you have an Azure Load Balancer with Basic SKU associated with a Azure Service Fabric cluster, please follow this migration guide to keep your cluster safe. Plan accordingly the migration path you will take based on your current load balancer configuration, number of node types, and workloads in your cluster.

To check the SKU of your existing load balancers, please navigate to the [Load Balancers](https://portal.azure.com/#view/Microsoft_Azure_Network/LoadBalancingHubMenuBlade/~/loadBalancers) resources in the Azure Portal. On the overview page, you will find the SKU information.

## Document overview

This document specifies the options available to upgrade a Azure Load Balancer with Basic SKU to a Standard SKU with Azure IP Address and Azure Load Balancer for a Azure Service Fabric cluster. Choose one of the options below based on availability requirements.

> [!NOTE]
> This does not apply to [Azure Service Fabric Managed Clusters](https://learn.microsoft.com/azure/service-fabric/overview-managed-cluster). Service Fabric Managed Clusters with Basic SKU are provisioned with a Azure Load Balancer on Basic SKU but cannot be upgraded and must be redeployed. Service Fabric Managed Clusters with Standard SKU have are provisioned with a Azure Load Balancer on Standard SKU and are not impacted.


## Migration decision guide 

The following table captures the risk and effort evaluation of the various migration options
| Scenario | Effort | Risk | Process | 
| --- | --- | --- | --- |
| Manual upgrade with no down time | High | Low | [Manual process](#manual-upgrade-process-with-no-down-time) |
| Automatic upgrade with downtime | Low | High | [Automatic process](#automated-upgrade-process-with-down-time) | 
| Cluster recreation | Medium | Low | - | 


