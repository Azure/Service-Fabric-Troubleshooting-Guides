# Continuation of container support in Azure Service Fabric

## Abstract 

Post 3rd Oct, 2022 Service Fabric customers using “with containers” VM images may face service disruptions as Microsoft will remove the “with container” VM images from the Azure image gallery. The VM image unavailability would lead to the failure of VM lifecycle management operations such as scale out, re-image, and service healing for Azure Service Fabric (SF) node types based on these VM images. 

Microsoft validated Service Fabric 9.0 CU1 or later with Mirantis Container Runtime v20.10.13 and Moby v20.10.18 on Windows Server 2019/2022. Please make yourself familiar with the support options of these container runtimes.
 
Please use our decision graph to get an overview: [Container Support Decision Graph](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Deployment/Container-Support-Decision-Graph.md)

## List of affected Azure OS images

Customer is using Windows Server image 2016 with Containers
- 2016-Datacenter-with-Containers 
- 2016-Datacenter-with-Containers-g2 
- 2016-Datacenter-with-Containers-GS 

Customer is using Windows Server image 2019 with Containers
- 2019-Datacenter-Core-with-Containers 
- 2019-Datacenter-core-with-containers-g2 
- 2019-Datacenter-Core-with-Containers-smalldisk 
- 2019-Datacenter-Core-with-Containers-smalldisk-g2 
- 2019-Datacenter-with-Containers 
- 2019-Datacenter-with-Containers-g2 
- 2019-Datacenter-with-Containers-GS 
- 2019-Datacenter-with-Containers-smalldisk 
- 2019-Datacenter-with-Containers-smalldisk-g2

## Migration risk decision guide

This guide is designed to help you assess the effort and risk of each migration option. 
Criteria for successfully running container runtime to host container on Azure Service Fabric cluster.
1. Choose a container runtime.
2. Service Fabric runtime needs to be on version [9.0 CU2 (9.0.1048.9590) or greater](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-versions).
3. Azure Virtual Machine Scale Sets to host containers on container runtime needs to run on Windows Server 2019/2022. 
4. The container runtime needs to be installed by Custom Script VM Extension or pre-installed as part of an OS image.

In-place SKU upgrades are in general not supported on Service Fabric cluster nodes, as such operations potentially involve data and availability loss. The safest, most reliable, and recommended method for scaling up a Service Fabric node type is to add a new node type and move the workload over.

In this document we are describing an approach to do an in-place OS SKU upgrade with less effort but the potential risk of ending up in a non-recoverable state. This approach should be only considered for Service Fabric Node Types without container workloads. Please read the described risks for each scenario carefully.

| Scenario | Effort | Risk | Node Types without container workloads | Node Types with container workloads |
| --- | --- | --- | --- | --- |
| In-place OS SKU upgrade | Low | High | Yes | No | 
| Mitigate by adding new node type with OS image without container support | Medium | Low | Yes | No |
| Mitigate by adding new node type with VM extension to install container runtime | High | Low | Yes | Yes |
| Mitigate by adding new node type with OS image by container runtime | Medium | Low | Yes | Yes |
| Mitigate by adding new primary node type with custom OS image with container runtime pre-installed | High | Low | Yes | Yes |
| Recreate the cluster resource | High | Low | Yes | Yes |

## Key questions

1.	Which Service Fabric Node Types are running container workloads?

    In case the Node Type is not running any container workload, then migrating to different Windows Server OS image will be sufficient. When safety is prioritized, then creating a new node type, and move the workload. For less safety, consider the in-place upgrade by only changing the OS SKU. 

    For container workloads, the mitigation is to move the workloads to a new node type with new container runtime. The container runtime can be installed by Custom Script VM Extension on the VMSS or pre-installed on OS image. Creating and maintaining a custom OS image is effort. Patching Windows and the container runtime must be considered. 

    Mirantis published an OS image in the Azure Marketplace with pre-installed Mirantis Container Runtime. 


2.	Are the running services on the Service Fabric Node Type allow downtime?

    Upgrading a VMSS with another OS image or moving workloads doesn’t involve any downtime as long as the design of the applications allow movements to another nodes and scale sets. The VMSS follows the concept of upgrade domains and Service Fabric controls going domain by domain as long as the durability level silver or higher is configured.

    The node type must be Silver or Gold durability level, because:
    - Bronze does not give you any guarantees about saving state information.
    - Silver and Gold durability trap any changes to the scale set.
    - Gold also gives you control over the Azure updates underneath scale set.

    In case one node type is serving as public endpoint, to reduce downtime a DNS switch by redirecting the traffic to a new Azure Public IP (PIP) address with Azure Traffic Manager or to another region is needed to keep downtime at minimum. Multiple zone scenarios are covered safely by the configuration sfZonalUpgradeMode:Hierarchical. In this way, only one zone goes through the upgrade at a time and the traffic is routed through one Azure Load Balancer on Standard SKU to all zones.

## Scenario 1: Customer is hosting Azure Service Fabric Node Type using deprecated Windows Server images with-Containers, but does NOT host containers in Docker as part of their overall applications

### Scenario 1/Option 1: Full rebuild the cluster

This scenario fits where availability loss is acceptable, and effort is less through automation.

Steps
1.	Full rebuild of Service Fabric cluster on a supported OS SKU without container support.
a.	Example for the OS SKU name: Windows Server 2022 Datacenter
2.	Re-deploy applications

> :exclamation:
> Please consider the option to recreate the cluster by only removing the Azure Virtual Machine Scale Sets (VMSS) and the Azure Service Fabric cluster resource. Creating just these two instances works well when you don’t automate the whole deployment.

Documentation:
- [Quickstart: Create a Service Fabric cluster using ARM template](https://docs.microsoft.com/en-us/azure/service-fabric/quickstart-cluster-template)
- [How To: Rebuild Azure Service Fabric cluster (minimal version)](#)

### Scenario 1/Option 2: Mitigate via OS SKU upgrade

The mitigation by adding a new Service Fabric Node Type and migrating the workload has the best cost benefit and the lowest risk in production.

#### Primary Node Type on deprecated OS SKU

Upgrade primary SKU to supported OS SKU without container support by following the linked documentation.

Documentation: 
- [Scale up a Service Fabric cluster primary node type](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-scale-up-primary-node-type)

#### Secondary Node Type on deprecated OS SKU

Add new secondary Node Types with supported OS SKU without container support by following the linked documentation.
        
Documentation: 
- [Scale a Service Fabric cluster out by adding a virtual machine scale set](https://docs.microsoft.com/en-us/azure/service-fabric/virtual-machine-scale-set-scale-node-type-scale-out)
- [Scale up a Service Fabric cluster secondary node type](#)

### Scenario 1/Option 3: Mitigate via OS SKU in-place upgrade

Azure Service Fabric Service allows an in-place upgrade by changing only the OS SKU and version parameter on the VMSS configuration. This upgrade explicitly excludes changes to publisher or offer, and also excludes any other change like the Azure VM SKU.

Requirements
- The Durability must be Silver or higher. Durability Bronze does not allow in-place upgrade.
- Disaster Recovery Plan must be tested and executable beforehand.
  [Disaster recovery in Azure Service Fabric](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-disaster-recovery)
- Backup all data of stateful services must exist.
  [Periodic backup and restore in an Azure Service Fabric cluster](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-quickstart-azurecluster)

Please take care of this pre-requisites before you start the process.

1. The cluster is healthy.
2. All other deployments are stopped during the time of the upgrade. 
3. Please make sure that no other configuration change is triggered. For example, do not change any parameters in the ARM template other than described below. 
4. There will still be sufficient capacity during the time nodes in one UD are going down, eg. number of nodes to place required replica count.
5. All stateful services need to follow the guidance to have sufficient replica count in place. Minimum TargetReplicaSetSize = 5, MinReplicaSetSize = 3.
  [Stateful service replica set size configuration](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-best-practices-replica-set-size-configuration)

> :warning:
> The rare but potential risk with the in-place upgrade is that in case of something gets stuck during the upgrade then there is no rollback option. In this case Microsoft cannot support in unblocking this scenario. Please do not use this scenario if the rebuild of the cluster is not acceptable.

#### What should be changed during the upgrade?

Only two parameters (sku, version) are allowed to be changed during the upgrade.
```json
"storageProfile": {
 "imageReference": {
  "publisher": "[parameters('vmImagePublisher')]",
  "offer": "[parameters('vmImageOffer')]",
  "sku": "[parameters('vmImageSku')]",
  "version": "[parameters('vmImageVersion')]"
 },
},
```

#### Example for the configuration change

Old parameter values:
```json
"sku": "2019-Datacenter-with-Containers",
"version": "latest"
```

New parameter values:
```json
"sku": "2019-Datacenter",
"version": "latest"
```

#### Migrate workloads

For each option, running workloads need to be moved by changing placement constraints or application upgrades.

Documentation:
- [Configuring placement constraints for Service Fabric services](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-resource-manager-configure-services#placement-constraints)
- [Service Fabric application upgrade](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-application-upgrade)
- [Stateful service replica set size configuration](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-best-practices-replica-set-size-configuration)

## Scenario 2: Customer is hosting Azure Service Fabric Node Type using deprecated Windows Server images with-Containers, and does host containers in Docker as part of their applications

In general, the steps are as follows:
1. Choose container runtime. 
2. Install container runtime on new node type. There are three options to install the container runtime:
   1. Custom Script VM Extension on a new node type with standard Azure OS image without container support. 
   Please find the guidance to install container runtime via Custom Script VM Extension in the respective scenario.
   The container runtime installer needs a machine restart to work during the post-deployment. This can potentially delay other operational processes, as scaling, node repair, reimage can take longer. The installer also checks if the latest version is installed, this can be disabled in the provided script.
   2. Create a new node type with the Azure Marketplace OS image provided by with pre-installed container runtime. 
   3. Create a custom OS image to pre-install container runtime. Please find guidance below in the documentation. VMSS also allows to use automatic OS image upgrade to install Windows patches on custom images.
3. Move workloads to new node type.

> :exclamation:
> The above steps to provision container runtime runtime were performed on Windows Server 2022 running Service Fabric 9.0 CU2   

### Scenario 2/Option 1: Full rebuild of Azure Service Fabric cluster (9.0 CU2 or later) on a supported Windows 2022 OS SKU 

This scenario fits where availability loss is acceptable, and effort is less through automation.

Steps
1. Full rebuild of Service Fabric cluster on a supported OS SKU without container support.
   Example for the OS SKU name: Windows Server 2022 Datacenter
2. Re-deploy applications

:exclamation: Please consider the option to recreate the cluster by only removing the Azure Virtual Machine Scale Sets (VMSS) and the Azure Service Fabric cluster resource. Creating just these two instances works well when you don’t automate the whole deployment.

Documentation:
- [Quickstart: Create a Service Fabric cluster using ARM template](https://docs.microsoft.com/en-us/azure/service-fabric/quickstart-cluster-template)
- [How To: Rebuild Azure Service Fabric cluster (minimal version)](#)
- [Install Mirantis on Azure Service Fabric via Custom Script VM Extension](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Deployment/Mirantis-Installation.md)

### Scenario 2/Option 2: Mitigate Node Types via OS SKU upgrade

Depending on the configuration of the Node Type you must follow different processes for primary or non-primary Node Types, documentation is linked below.

Upgrade Azure Service Fabric runtime version.

- [Upgrade the Service Fabric version that runs on your cluster](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-upgrade-windows-server)
- [Service Fabric supported versions](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-versions)

Adding a new node type safely in Azure Service Fabric cluster.

- [Scale up a Service Fabric cluster primary node type](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-scale-up-primary-node-type)
- [Scale a Service Fabric cluster out by adding a virtual machine scale set](https://docs.microsoft.com/en-us/azure/service-fabric/virtual-machine-scale-set-scale-node-type-scale-out)

Install container runtime during post-deployment with Custom Script VM Extension on VMSS.

- [Install Mirantis on Azure Service Fabric via Custom Script VM Extension](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Deployment/Mirantis-Installation.md)
- [Install MCR on Windows Servers](https://docs.mirantis.com/mcr/20.10/install/mcr-windows.html)
- [Install Docker CE/Moby on Windows Server](https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment?tabs=dockerce#windows-server-1)
- [Sequence extension provisioning in virtual machine scale sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing)
- [Custom Script Extension for Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows)

Find OS image with pre-installed container runtime provided in Azure Marketplace (September 2022).

- [Find and use Azure Marketplace VM images with Azure PowerShell](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage)
- [Azure Marketplace - Windows Server 2019 Datacenter with Containers (Mirantis Container Runtime)](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/mirantis.windows_with_mirantis_container_runtime_2019)

Create a custom OS image to build a new node type with it.

- [Get started: Prep Windows for containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment)
- [Automatic OS image upgrade for custom images](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade#automatic-os-image-upgrade-for-custom-images)

Running workloads need to be moved by changing placement constraints or application upgrades.

- [Configuring placement constraints for Service Fabric services](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-resource-manager-configure-services#placement-constraints)
- [Service Fabric application upgrade](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-application-upgrade)

After successful migration, the unused Node Type should be removed.
- [How to remove a Service Fabric node type](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-how-to-remove-node-type)
- [Remove the original node type and cleanup its resources](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-scale-up-primary-node-type#remove-the-original-node-type-and-cleanup-its-resources)

Additional guidance related to container runtimes
- Modifications to the Docker data root (C:\ProgramData\docker) must be tested before doing the migration.
- Other container runtimes like for example containerd or DockerEE should not be installed side-by-side with other container runtimes.
- Container images must recreated when changing the Windows Server major version. This is not relevant for Windows containers using the [Hyper-V isolation mode](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-containers-overview#service-fabric-support-for-containers).

## Scenario 3: Customer has Azure Service Fabric Managed Cluster using deprecated Windows Server images with-Containers, and does NOT host containers in Docker as part of their applications

Customers in this scenario can simply use the in-place upgrade to switch to another OS SKU without container support and moving the workloads.
Documentation:
- [Modify the OS SKU for a node type](https://docs.microsoft.com/en-us/azure/service-fabric/how-to-managed-cluster-modify-node-type#modify-the-os-sku-for-a-node-type)
- [Configuring placement constraints for Service Fabric services](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-resource-manager-configure-services#placement-constraints)
- [Service Fabric application upgrade](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-application-upgrade)

Scenario 4: Customer has Azure Service Fabric Managed Cluster using deprecated Windows Server images with-Containers, and does host containers in Docker as part of their applications

Service Fabric Managed Cluster release support for custom OS images in beginning of September 2022. Please stay tuned for the official announcement.
Documentation:
- [Get started: Prep Windows for containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment)
- [Automatic OS image upgrade for custom images](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade#automatic-os-image-upgrade-for-custom-images)


## Frequently Asked Questions

For all further questions please reach out to your account team or [create a Microsoft support case](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request).

1. Which container runtimes are supported by Service Fabric?

   Microsoft validated Service Fabric 9.0 CU1 or later with Mirantis Container Runtime v20.10.13 and Moby v20.10.18 on Windows Server 2019/2022. Please make yourself familiar with the support options of these container runtimes.
   - Moby is an open-source container runtime, former DockerCE. 
   - Mirantis Container Runtime, former DockerEE. 

