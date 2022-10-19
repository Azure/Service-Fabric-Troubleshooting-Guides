# SFRP VMSS Validations

>[Overview](#overview)  
>[Upcoming Validations](#upcoming-validations)
>>[MinVMCountValidation](#minvmcountvalidation)
>>[WindowsUpdatesValidation](#windowsupdatesvalidation)
>
>[Existing Validations](#existing-validations)  
>[FAQ](#faq)

## Overview  

In SFRP Clusters the VMSS resource is a separate entity controlled by customers. In order to ensure that customers do not put their resources in bad states or states that will lead to negative consequences (cluster going down etc.) we have added various validations that get triggered on VMSS deployments. In this document we will go through the current validations and future validations that will be getting enabled.

## Upcoming Validations

### MinVMCountValidation

#### Summary

- This validator is being introduced to validate the minimum virtual machine count configuration meets the durability requirements for "Silver" and "Gold." This has been a documented requirement to ensure reliable and safe infrastructure updates can occur for production workloads. Per this policy, Service Fabric Resource Provider node types with virtual machine scale set "Silver" or "Gold" durability tiers should always have at least 5 virtual machines. Having misconfiguration leads to various reliability issues while performing infrastructure updates (such as AutoOSUpgrades, scale out/in, platform updates, etc.) and can lead to availability or data loss.

#### Error Message

- NodeType {0} with VMSS Durability {1} should have atleast 5 VMs but actually has {2} VMs. If you need to deploy with less than 5 VMs, please consider using Durability = Bronze, but this is not recommended for Production clusters. For details: <https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-capacity#durability-characteristics-of-the-cluster>";

#### Mitigation

- Scale up the nodetype to 5+ nodes
- If the cluster is a testing cluster you can consider changing the durability to bronze but this isn't recommended for production

### WindowsUpdatesValidation

#### Summary

- This validator is being introduced to validate that VMSS with durability of Silver or Gold should always have Windows Update explicitly disabled to avoid unintended OS restarts due to the Windows updates, which can impact the production workloads. This can be done by setting the `properties.virtualMachineProfile.osProfile.windowsConfiguration.enableAutomaticUpdates: false`, in the VMSS OSProfile. Instead please enable Automatic VMSS Image upgrades instead - for more details, please follow the doc: <https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade>.
For more information see: VMSS Image Upgrades

#### Error Message

- This update will make your cluster vulnerable to multiple nodes of NodeType: {0} going down at the same time due to windows updates. Current durability: {1}, stateless: {2}. For durability silver and up automatic OS upgrades are recommended. Disable WindowsUpdates in the OSProfile of the VMSS by setting \"enableAutomaticUpdates\": false. For more details, please follow the doc: <https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade>;

#### Mitigation

- Explicitly set `properties.virtualMachineProfile.osProfile.windowsConfiguration.enableAutomaticUpdates: false`, in the VMSS OSProfile
- Follow the details in this doc to set up auto os upgrades for your SF cluster <https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade>

## Existing Validations

Coming soon ...

## FAQ

1. I received a notification saying that my cluster was violating one of these validators, however, the cluster doesn't seem to currently exist?

> This would indicate that you at one point had a cluster that was violating one of these validators. Please review your templates and ensure you are following best practices for a SFRP VMSS
