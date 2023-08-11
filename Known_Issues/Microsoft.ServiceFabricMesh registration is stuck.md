# Microsoft.ServiceFabricMesh registration is stuck

## Issue
Customers using terraform see Microsoft.ServiceFabricMesh provider get stuck during registration. This is because ServiceFabricMesh Resource Provider is still within the list of available providers but it has been deprecated, read more about this [here](https://azure.microsoft.com/en-us/updates/azure-service-fabric-mesh-preview-retirement/). ServiceFabricMesh was part of the list of default providers to register from Terraform. 

## Impact
Customers that use terraform usually are stuck from deployments because of this error. They should not be trying to manually register this RP either. 

## Symptoms
When deploying using terraform customers will see the process of registering/unregistering Microsoft.ServiceFabricMesh stuck in Azure Portal and errors stating that the provider has not been registered. 



## Mitigation

To mitigate, customers should use azurerm provider versions v3.41.0 or later. Terraform has taken out the ServiceFabricMesh provider from the providers list for these newer versions.

**Steps**:

Update the azurerm provider version in the terraform template 

    ```
    terraform {
      required_providers {
        aurerm = {
        ...
        version = "=3.41.0"
        }
      }
    }
    ```
