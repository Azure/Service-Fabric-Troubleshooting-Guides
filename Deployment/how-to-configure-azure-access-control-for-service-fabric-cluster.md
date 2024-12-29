# How to configure Azure Access control (IAM) for a Service Fabric Cluster

The steps below describe how to configure Azure Access control Custom Roles for Service Fabric clusters. This configuration is based on default deployment parameters and may need to be adjusted based on specific requirements. These steps have been tested with Service Fabric clusters deployed in Azure as a default Entra constrained user that is not the subscription owner / administrator.

## Process

- Verify [Requirements](#requirements)
- Create Azure Resource Group for Service Fabric cluster
- [Create Azure Subscription Custom Role Definition](#create-azure-subscription-custom-role-definition)
- [Assign Azure Subscription Custom Role to Entra constrained user](#assign-azure-subscription-custom-role-to-entra-constrained-user)
- [Create Azure Resource Group Custom Role Definition](#create-azure-resource-group-custom-role-definition)
- [Assign Azure Resource Group Custom Role to Entra constrained user](#assign-azure-resource-group-custom-role-to-entra-constrained-user)
- [Assign Service Fabric built-in roles to Entra constrained user](#assign-service-fabric-built-in-roles-to-entra-constrained-user)
    - Service Fabric Cluster Contributor
    - Service Fabric Managed Cluster Contributor
- Assign Entra constrained user to Azure Key Vault Access Policy
- Assign any additional roles to Entra constrained user necessary for custom deployment
- Test Entra constrained user configuration

## Requirements

- Administrative access to Azure Subscription and Resource Group that allows creation of custom roles and assignment of roles.
- Default Service Fabric cluster deployment consisting of:
  - Service Fabric Cluster
  - Virtual Network
  - Public IP Address
  - Load Balancer
  - Virtual Machine Scale Set
  - Storage Accounts
- Entra constrained user that will be assigned the following roles:
  - Azure Key Vault Access Policy
  - Azure Subscription Custom Role
  - Azure Resource Group Custom Role
  - Service Fabric Cluster Contributor

## Azure Portal Subscription Configuration

To configure Azure Access control (IAM) for Service Fabric cluster deployments, currently, a custom role at the subscription level is required. This is necessary to allow the Entra constrained user to deploy Service Fabric clusters in the subscription. The custom roles should be created with the minimum permissions required for Service Fabric cluster deployments.

### Subscription Access Control (IAM)

- Login to [Azure Portal](https://portal.azure.com) as a subscription owner / administrator
- On the Subscription blade, select Access control (IAM), then select Add custom role
- Fill in the required fields
- JSON definition for the custom role is provided below. This definition should be modified with subscription id and required permissions.

#### Create Azure Subscription Custom Role Definition

```json
{
  "properties": {
    "roleName": "service fabric subscription custom role for deployments",
    "description": "",
    "assignableScopes": [
      "/providers/Microsoft.Management/managementGroups/<subscription id>"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.ServiceFabric/locations/*/read",
          "Microsoft.KeyVault/vaults/deploy/action"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
```

#### Assign Azure Subscription Custom Role to Entra constrained user

- On the Subscription blade, select Access control (IAM), then select Add role assignment
- Select the custom role created in the previous step
- Select the Entra constrained user
- Select Review + assign

## Azure Portal Resource Group Configuration

To configure Azure Access control (IAM) for Service Fabric cluster deployments, a custom role at the resource group level is required. This is necessary to allow the Entra constrained user to deploy Service Fabric clusters in the resource group. The custom roles should be created with the minimum permissions required for Service Fabric cluster deployments.

### Resource Group Access Control (IAM)

#### Create Azure Resource Group Custom Role Definition

- Login to [Azure Portal](https://portal.azure.com) as a subscription owner / administrator
- On the Resource Group blade, select Access control (IAM), then select Add custom role
- Fill in the required fields
- JSON definition for the custom role is provided below. This definition should be modified with subscription id, resource group and required permissions.

```json
{
  "properties": {
    "roleName": "service fabric resource group custom role for deployments",
    "description": "",
    "assignableScopes": [
      "/subscriptions/<subscription id>/resourceGroups/<resource group>"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.Storage/storageAccounts/write",
          "Microsoft.Network/virtualNetworks/write",
          "Microsoft.Network/publicIPAddresses/write",
          "Microsoft.Network/loadBalancers/write",
          "Microsoft.Compute/virtualMachineScaleSets/write"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
```

#### Assign Azure Resource Group Custom Role to Entra constrained user

- On the Resource Group blade, select Access control (IAM), then select Add role assignment
- Select the custom role created in the previous step
- Select the Entra constrained user
- Select Review + assign

## Assign Service Fabric built-in roles to Entra constrained user

- On the Resource Group blade, select Access control (IAM), then select Add role assignment
- Select one of the built-in roles:
    - Service Fabric Cluster Contributor
    - Service Fabric Managed Cluster Contributor
- Select the Entra constrained user
- Select Review + assign

## Assign Entra constrained user to Azure Key Vault Access Policy

## Assign any additional roles to Entra constrained user necessary for custom deployment

## Testing Entra constrained user configuration

### Azure Portal Service Fabric cluster deployment

- Login to [Azure Portal](https://portal.azure.com) as Entra constrained user
- Select Resource Group
- Select +Create
- Select [Service Fabric Cluster](https://portal.azure.com/#create/Microsoft.ServiceFabricCluster) or [Service Fabric Managed Cluster](https://portal.azure.com/#create/Microsoft.ManagedServiceFabricCluster)
- Fill in the required fields

### PowerShell Service Fabric cluster deployment

```powershell
# connect to Azure with global admin account
Connect-AzAccount -TenantId <tenant id> -SubscriptionId <subscription id>
# create new service fabric cluster arm template deployment
New-AzResourceGroupDeployment -ResourceGroupName <resource group> -TemplateFile <template file> -TemplateParameterFile <parameters file>
```

## Scenarios

- Azure Portal Service Fabric cluster deployment
- PowerShell Service Fabric cluster deployment
- Azure Portal Service Fabric managed cluster deployment
- PowerShell Service Fabric managed cluster deployment

## PowerShell commands

### Creating custom role definitions

```powershell
# connect to Azure with global admin account
Connect-AzAccount -TenantId <tenant id> -SubscriptionId <subscription id>
# create role definition
$roleDefinition = @'
{
  "properties": {
    "roleName": "service fabric subscription custom role for deployments",
    "description": "",
    "assignableScopes": [
      "/providers/Microsoft.Management/managementGroups/<subscription id>"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.ServiceFabric/locations/*/read",
          "Microsoft.KeyVault/vaults/deploy/action"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
'@
New-AzRoleDefinition -InputObject $roleDefinition

$roleDefinition = @'
{
  "properties": {
    "roleName": "service fabric resource group custom role for deployments",
    "description": "",
    "assignableScopes": [
      "/subscriptions/<subscription id>/resourceGroups/<resource group>"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.Storage/storageAccounts/write",
          "Microsoft.Network/virtualNetworks/write",
          "Microsoft.Network/publicIPAddresses/write",
          "Microsoft.Network/loadBalancers/write",
          "Microsoft.Compute/virtualMachineScaleSets/write"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
'@
New-AzRoleDefinition -InputObject $roleDefinition
```

### Assigning custom role definitions to user

```powershell
# connect to Azure with global admin account
Connect-AzAccount -TenantId <tenant id> -SubscriptionId <subscription id>

# assign subscription role definition
New-AzRoleAssignment -SignInName <user email> -RoleDefinitionName "service fabric subscription custom role for deployments" -Scope "/providers/Microsoft.Management/managementGroups/<subscription id>"

# assign resource group role definition
New-AzRoleAssignment -SignInName <user email> -RoleDefinitionName "service fabric resource group custom role for deployments" -Scope "/subscriptions/<subscription id>/resourceGroups/<resource group>"
```

### Enumerating role definitions and role assignments

```powershell
# connect to Azure with global admin account
Connect-AzAccount -TenantId <tenant id> -SubscriptionId <subscription id>

# get subscription role definition
Get-AzRoleDefinition -Name "service fabric subscription custom role for deployments"

# get resource group role definition
Get-AzRoleDefinition -Name "service fabric resource group custom role for deployments"

# get role assignment
Get-AzRoleAssignment -SignInName <user email>
```

## Built-in roles

### Service Fabric Cluster Contributor

```json
{
  "id": "/providers/Microsoft.Authorization/roleDefinitions/b6efc156-f0da-4e90-a50a-8c000140b017",
  "properties": {
    "roleName": "Service Fabric Cluster Contributor",
    "description": "Manage your Service Fabric Cluster resources. Includes clusters, application types, application type versions, applications, and services. You will need additional permissions to deploy and manage the cluster's underlying resources such as virtual machine scale sets, storage accounts, networks, etc.",
    "assignableScopes": [
      "/"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.ServiceFabric/clusters/*",
          "Microsoft.Authorization/*/read",
          "Microsoft.Insights/alertRules/*",
          "Microsoft.Resources/deployments/*",
          "Microsoft.Resources/subscriptions/resourceGroups/read"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
```

### Service Fabric Managed Cluster Contributor

```json
{
  "id": "/providers/Microsoft.Authorization/roleDefinitions/83f80186-3729-438c-ad2d-39e94d718838",
  "properties": {
    "roleName": "Service Fabric Managed Cluster Contributor",
    "description": "Deploy and manage your Service Fabric Managed Cluster resources. Includes managed clusters, node types, application types, application type versions, applications, and services.",
    "assignableScopes": [
      "/"
    ],
    "permissions": [
      {
        "actions": [
          "Microsoft.ServiceFabric/managedclusters/*",
          "Microsoft.Authorization/*/read",
          "Microsoft.Insights/alertRules/*",
          "Microsoft.Resources/deployments/*",
          "Microsoft.Resources/subscriptions/resourceGroups/read"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
```

## Reference

- https://learn.microsoft.com/azure/azure-resource-manager/management/azure-services-resource-providers
- https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
- https://learn.microsoft.com/azure/role-based-access-control/custom-roles
- https://learn.microsoft.com/azure/role-based-access-control/role-assignments
- https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal
- https://learn.microsoft.com/azure/role-based-access-control/role-assignments-steps
- https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-to-resource-group
