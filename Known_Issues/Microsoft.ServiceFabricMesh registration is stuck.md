# Microsoft.ServiceFabricMesh registration is stuck

## Issue
Customers using terraform see Microsoft.ServiceFabricMesh provider get stuck during registration. This is because ServiceFabricMesh Resource Provider is still within the list of available providers but it has been deprecated, read more about this [here](https://azure.microsoft.com/en-us/updates/azure-service-fabric-mesh-preview-retirement/). ServiceFabricMesh was part of the list of default providers to register from Terraform. 

## Impact
Customers that use terraform usually are stuck from deployments because of this error. They should not be trying to manually register this RP either. 

## Symptoms
- When deploying using terraform customers will get the following error:

  ```
  Cannot register provider Microsoft.ServiceFabricMesh with Azure Resource Manager: resources.ProvidersClient
  ```
 
- In the Azure Portal the process of registering/unregistering Microsoft.ServiceFabricMesh gets stuck in "registering/unregistering" status:
  
 ![image](https://github.com/dbucce/Service-Fabric-Troubleshooting-Guides/assets/50681801/8a20f940-e9ba-404c-9909-c8fd1796e374)

- Timeout errors from portal when trying to register/unregister RP:

```
'Unregister' operation check timed out on Resource Provider 'microsoft.servicefabricmesh', please refresh resource providers list to check for registration status
```

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
