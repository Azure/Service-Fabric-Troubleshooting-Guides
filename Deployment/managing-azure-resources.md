# Managing Azure Resources

Multiple methods are available to manage Azure resources. The [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview) in Azure Portal provides a unified interface with both [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer) for browsing resources and [ARM API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground) for making modifications. The alternatives listed below provide comprehensive ways to view and modify Azure resources programmatically or through a graphical interface:

1. **Azure Portal**: Azure Portal is the primary interface for managing Azure resources. The [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview) blade provides integrated access to:
   - **Resource Explorer**: Browse and view resources in a hierarchical tree structure (read-only)
   - **ARM API Playground**: Execute GET, PUT, PATCH, and DELETE operations on Azure Resource Manager APIs

   - **Advantages**: User-friendly, comprehensive, integrated interface for both browsing and modifying resources.
   - **Disadvantages**: Requires a browser. May be cumbersome for large-scale operations or automation tasks.
2. **Azure PowerShell**: Azure PowerShell is a set of cmdlets for managing Azure resources from the command line. It is particularly useful for Windows environments and integrates seamlessly with other PowerShell scripts and modules.

   - **Advantages**: Powerful scripting capabilities commonly used in Azure automation with the ability to access detailed resource information.
   - **Disadvantages**: Requires knowledge of PowerShell syntax and may not be as user-friendly for those unfamiliar with PowerShell.
3. **Azure CLI**: Similar to Azure PowerShell, the Azure Command-Line Interface (CLI) is a cross-platform command-line tool that allows you to manage Azure resources. It provides commands for creating, updating, and deleting resources, as well as querying resource information.

   - **Advantages**: Scriptable, can be used in automation scripts, and provides detailed information about resources.
   - **Disadvantages**: Requires knowledge of command-line syntax and may not be as user-friendly for those unfamiliar with CLI tools.

## Azure Portal

The Azure Portal provides a unified [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview) blade for managing and viewing Azure resources. This blade contains two main tools:

- **[Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer)**: Allows graphical navigation and browsing of resources (read-only)
- **[ARM API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground)**: Enables executing ARM API operations (GET, PUT, PATCH, DELETE) to view and modify resources

The following steps demonstrate how to view and modify resources using this unified interface:

### Using Azure Portal to view resources

1. Open [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview) in [Azure Portal](https://portal.azure.com/). The Resource Manager blade provides an overview with quick access to both Resource Explorer and ARM API Playground.

   ![Resource Manager Overview](../media/managing-azure-resources/azure-portal-fixed.png)

2. Click on **Resource Explorer** in the left navigation or use the direct link to [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer) to browse resources.

3. Select the specific subscription, resource group, and then resource under 'Resources':

   ```text
   Subscriptions
       └───<subscription name>
           └───ResourceGroups
               └───<resource group name>
                   └───Resources
                       └───<resource name>
   ```

   ![Resource Explorer](../media/managing-azure-resources/resource-explorer-obfuscated.png)

4. Expand the resource to view its properties and configuration. For example, expanding a Virtual Machine Scale Set resource shows details about the VMSS configuration:

   ![VMSS Resource Details](../media/managing-azure-resources/resource-vmss-nodetype0.png)

5. To modify this resource, note the resource path and API version displayed in Resource Explorer, which will be needed for the ARM API Playground in the next section.

### Using Azure Portal to update resources

To use [ARM API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground) to modify resource configuration, the resource URI with API version must be provided. You can obtain this from [Resource Explorer](#using-azure-portal-to-view-resources) or from the `Resource JSON` view available on most resource blades in Azure Portal. The `Resource JSON` view can be accessed by selecting the `JSON View` link on the top right side of the resource blade.

The resource URI format is as follows:

```text
/<subscription id>/resourceGroups/<resource group name>/providers/<resource provider>/<resource type>/<resource name>?api-version=<api version>
```

#### Workflow for modifying resources

1. From the [Resource Manager](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview) blade, click on **ARM API Playground** in the left navigation or use the direct link to [ARM API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground).

   ![ARM API Playground Workflow](../media/managing-azure-resources/arm-api-put-workflow.png)

2. Enter the resource URI with API version in the request URL field. Select **GET** as the HTTP method and click **Execute** to retrieve the current configuration. Example showing a Service Fabric cluster resource:

   ![ARM API Get Request](../media/managing-azure-resources/arm-api-servicefabric-cluster.png)

3. The **Response** section will display the current configuration of the resource in JSON format. Copy this response body to use as the basis for your modifications.

4. Switch to the **Request body** tab, paste the copied JSON, and make your desired modifications to the configuration.

5. Change the HTTP method to **PUT** and click **Execute** to submit the updated configuration. Example showing a VMSS update:

   ![ARM API Put Request](../media/managing-azure-resources/arm-api-put-vmss-nodetype0.png)

6. The **Response** section will show the result of the operation. Verify the status code is `200 OK` and the `provisioningState` is `Updating` or `Succeeded`. You can monitor the provisioning status in the [Azure Portal](https://portal.azure.com/) or by performing additional GET requests from [ARM API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground).

## Azure PowerShell

> [!NOTE]
> These steps require Azure PowerShell 'Az' modules. Specifically, `Az.Accounts` and `Az.Resources` are the two modules being used. If these are not installed, they can be installed using the following commands.

Connect to an Azure account with the [`Connect-AzAccount`](https://learn.microsoft.com/powershell/module/az.accounts/connect-azaccount) cmdlet. This will prompt for credentials and allow selection of the subscription to work with. If multiple subscriptions are available, the subscription name or ID can be specified using the `-Subscription` parameter.

1. Open Azure PowerShell and authenticate to the Azure account:

```powershell
  # install all Az modules
  #Install-Module -Name Az -AllowClobber -Force

  # or install specific Az modules
  # Install-Module -Name Az.Accounts -AllowClobber -Force
  # Install-Module -Name Az.Resources -AllowClobber -Force

  Import-Module Az.Accounts
  Import-Module Az.Resources
  Connect-AzAccount
```

### Using PowerShell to view resources

The following steps demonstrate how to view resources with PowerShell:

1. Use the [`Get-AzResource`](https://learn.microsoft.com/powershell/module/az.resources/get-azresource) cmdlet to list all resources in a specific resource group:

   ```powershell
   $resources = Get-AzResource -ResourceGroupName <resource group name>
   $resources
   ```
2. To view a specific resource, use the [`Get-AzResource`](https://learn.microsoft.com/powershell/module/az.resources/get-azresource) cmdlet with the `-ResourceId` parameter:

   ```powershell
   $resource = Get-AzResource -ResourceId <resource id>
   $resource
   ```

### Using PowerShell to update resources

The following steps demonstrate how to update resources with PowerShell:

1. Use the [`Set-AzResource`](https://learn.microsoft.com/powershell/module/az.resources/set-azresource) cmdlet to update the resource. For example, to update a property of a resource:

   ```powershell
    Set-AzResource -ResourceId <resource id> -Properties @{<property name> = <new value>}
   ```
2. To verify the update, use the [`Get-AzResource`](https://learn.microsoft.com/powershell/module/az.resources/get-azresource) cmdlet again:

   ```powershell
   Get-AzResource -ResourceId <resource id>
   ```

### Using PowerShell to export ARM template

Use the [`Export-AzResourceGroup`](https://learn.microsoft.com/powershell/module/az.resources/export-azresourcegroup) cmdlet to export an ARM template for a specific resource or resource group. The exported template can be modified and then used to update the resource configuration. The `-SkipAllParameterization` parameter is used to skip parameterization of all properties in the exported template. The `-Force` parameter is used to overwrite the existing file if it already exists.

> [!NOTE]
> Exporting Service Fabric clusters (unmanaged) with a basic load balancer at the resource group level is not supported. There are known issues with exporting load balancer rules for a basic load balancer. If using `Export-AzResourceGroup` for unmanaged clusters with a basic load balancer, specify the resource ID of the resource to update instead of the resource group. This is not an issue with standard load balancers.

Variables used in the following examples:

```powershell
  $resourceGroupName = "<resource group name>"
  $jsonFile = "$pwd\template.json"
  $resourceId = "<resource id>"
```

To export an ARM template with PowerShell for a specific resource:

```powershell
  Export-AzResourceGroup -ResourceGroupName $resourceGroupName `
    -Resource $resourceId `
    -Path $jsonFile `
    -SkipAllParameterization `
    -Force
```

To export an ARM template with PowerShell for an entire resource group:

```powershell
  Export-AzResourceGroup -ResourceGroupName $resourceGroupName `
    -Path $jsonFile `
    -SkipAllParameterization `
    -Force
```

### Using PowerShell to deploy ARM template

Use the [`New-AzResourceGroupDeployment`](https://learn.microsoft.com/powershell/module/az.resources/new-azresourcegroupdeployment) cmdlet to deploy the modified ARM template. The `-TemplateFile` parameter is used to specify the path to the updated template file.

```powershell
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile $jsonFile `
  -Verbose
```

## Azure CLI

> [!NOTE]
> These steps require Azure CLI. If Azure CLI is not installed, it can be installed by following the instructions in the [Azure CLI installation guide](https://learn.microsoft.com/cli/azure/install-azure-cli).

Connect to an Azure account with the [`az login`](https://learn.microsoft.com/cli/azure/authenticate-azure-cli) command. This will prompt for credentials and allow selection of the subscription to work with. If multiple subscriptions are available, the subscription name or ID can be specified using the `--subscription` parameter.

1. Open the command line interface and authenticate to the Azure account:

   ```bash
   az login
   ```

### Using Azure CLI to view resources

The following steps demonstrate how to view resources with Azure CLI:

1. Use the [`az resource list`](https://learn.microsoft.com/cli/azure/resource#az_resource_list) command to list all resources in a specific resource group:

   ```bash
   az resource list --resource-group <resource group name>
   ```

### Using Azure CLI to update resources

The following steps demonstrate how to update resources with Azure CLI:

1. Use the [`az resource update`](https://learn.microsoft.com/cli/azure/resource#az_resource_update) command to update the resource. For example, to update a property of a resource:

   ```bash
   az resource update --ids <resource id> --set <property name>=<new value>
   ```

## Additional Information

### Microsoft Learn

Resource schema and API version for a specific resource can be found in the Microsoft Learn documentation. Each resource type has its own documentation page that includes the API version information. Search for the resource type in the Microsoft Learn documentation and select the API version dropdown at the top of the page.

[Azure Templates](https://learn.microsoft.com/azure/templates/) contains comprehensive information for all Azure Resources.

### Obtaining Resource ID

The resource ID is a unique identifier for an Azure resource. It can be obtained from different blades in Azure Portal, Azure PowerShell, or Azure CLI. It can also be generated using the resource ID format below.

#### Obtaining Resource ID via Azure Portal

The resource ID can be obtained from multiple locations in Azure Portal:

1. **Using [Resource Manager - Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer)**: Navigate to your resource in the hierarchical tree view. The resource path is displayed in Resource Explorer and can be combined with the subscription ID to form the complete resource ID.

2. **Using the resource blade**: Open Azure Portal and navigate to the resource. Select the `JSON View` link on the top right side of the resource blade. This will open a panel with the JSON representation of the resource, including the resource ID and available API versions.

   ![Resource View](../media/resource-explorer-steps/portal-resource-view.png)

- The resource ID will be displayed in the `Resource ID` field of the JSON representation.
- The API version can be found in the `API Versions` field of the JSON representation.

  ![Json View](../media/resource-explorer-steps/portal-json-view.png)

#### Obtaining Resource ID via Azure PowerShell

There are multiple commands that can obtain the resource ID using Azure PowerShell. As noted above, the [`Get-AzResource`](https://learn.microsoft.com/powershell/module/az.resources/get-azresource) cmdlet can be used. This cmdlet retrieves resources in a specified resource group or subscription using different parameters.

Examples:

```powershell
  Get-AzResource -ResourceGroupName <resource group name> [-Name <resource name>] [-ResourceType <resource type>]
```

#### Obtaining Resource ID via Azure CLI

```bash
az resource show --resource-group <resource group name> --name <resource name> --resource-type <resource type> --query "id"
```

### Generating Resource ID

The resource ID can be generated using the following format, where `<subscription id>`, `<resource group name>`, `<resource provider>`, `<resource type>`, `<resource name>`, and `<api version>` are replaced with the appropriate values for the resource:

```text
/<subscription id>/resourceGroups/<resource group name>/providers/<resource provider>/<resource type>/<resource name>?api-version=<api version>
```

### Obtaining API Version

All Azure resources have a specific API version that is used to interact with the resource. The API version can be obtained from Azure Portal, Azure PowerShell, or Azure CLI. It can also be found in the Microsoft Learn documentation for the specific resource.

#### Obtaining API Version via Azure Portal

The API version can be found in multiple locations:

1. **Resource Manager - Resource Explorer**: When viewing a resource in [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer), the API version is displayed alongside the resource information.

2. **JSON View**: As noted above, the API version can be found in the `JSON View` of the resource in Azure Portal. The API version is displayed in the `API Versions` field of the JSON representation of the resource.

![Json View](../media/resource-explorer-steps/portal-json-view.png)

#### Obtaining API Version via Azure PowerShell

Use the `Get-AzResourceProvider` cmdlet to get the available API versions for a specific resource type. The API versions are listed under the `ApiVersions` property of the resource type.

```powershell
$resourceProvider = Get-AzResourceProvider -ProviderNamespace "<resource provider name>" # Microsoft.ServiceFabric, Microsoft.Compute, etc.
$resourceTypeInfo = $resourceProvider.ResourceTypes | Where-Object ResourceTypeName -ieq "<resource type>" # clusters, managedClusters, etc.
$apiVersions = $resourceTypeInfo.ApiVersions
$apiVersions
```

#### Obtaining API Version via Azure CLI

```bash
az provider show --namespace <resource provider name> --query "resourceTypes[?resourceType=='<resource type>'].apiVersions" -o json
```

#### API Version via Microsoft Learn

Example for Service Fabric clusters:

[Service Fabric Cluster Resource](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/clusters)

![Service Fabric Cluster Resource](../media/resource-explorer-steps/service-fabric-cluster-resource.png)
