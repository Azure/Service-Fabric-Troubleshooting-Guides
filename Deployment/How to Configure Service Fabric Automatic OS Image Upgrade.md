# How to Configure Service Fabric Automatic OS Image Upgrade

This article describes how to configure Service Fabric automatic OS image upgrade for management of Windows OS hotfixes and security updates. This is a best practice for Service Fabric clusters running in production. See [Automatic OS image upgrade](https://learn.microsoft.com/azure/service-fabric/how-to-patch-cluster-nodes-windows) for more information including information about Patch Orchestration Application (POA) and how to configure it if unable to use automatic OS image upgrade.

## Service Fabric Clusters

### Configuring 'Silver' or higher nodetype durability tier

> **Note**
> Changing durability tier requires updating both the virtual machine scale set resource and the nested nodetype array in the cluster resource.

To use automatic OS image upgrade, the nodetype durability tier must be set to 'Silver' or higher. This is the default and recommended setting for new clusters. 


## Service Fabric Managed Clusters

Service fabric managed clusters durability tier is set at  deployment time and cannot be changed after deployment. The default durability tier is 'Silver' for 'Standard' clusters and 'Bronze' for 'Basic' clusters. See [Service Fabric managed clusters](https://docs.microsoft.com/azure/service-fabric/service-fabric-managed-cluster-overview) for more information.
