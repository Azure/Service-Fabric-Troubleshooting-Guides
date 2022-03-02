## **Experimental Feature - How To Turn Off Resource Orchestrator Service**
The Resource Orchestrator Service is an experimental feature that is currently in development. It is currently not meant for production use and is by default set to off. However, if your cluster finds itself it a situation where the Resource Orchestrator Service is turned on, this document describes how to turn it off.

## **Verify Resource Orchestrator Service Has Been Turned On**
You can verify that the Resource Orchestrator Service is turned on in your cluster by looking at the health events in Service Fabric Explorer. There should be a health event that indicates the experimental feature "Resource Orchestrator Service" has been turned on. It should look similar to the image below.

![ROSExperimentalFeature.jpg](../media/ROSExperimentalFeature.jpg)

## **Turn Off Resource Orchestrator Service**
To turn off the Resource Orchestrator Service, the EnableResourceOrchestrator configuration in the FailoverManager section of the cluster's configuration needs to be set to False. 

| **Parameter** | **Allowed Values** | **Upgrade Policy** | **Guidance or Short Description** |
| --- | --- | --- | --- |
|EnableResourceOrchestrator|Bool, default is FALSE |Static|Flag that controls if the Resource Orchestrator Service is enable. |

For more information on how to modify cluster configuration settings for your cluster, see this page: https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-fabric-settings

**Note** - the EnableResourceOrchestrator configuration has a static upgrade policy, which means the nodes will need to be restarted to pickup the change.
