# Azure Resource Explorer Alternatives

With the deprecation of Azure Resource Explorer `https://resources.azure.com/`, there are alternatives to manage and explore their Azure resources. Below are some that can be used instead of Azure Resource Explorer:

1. **Azure Portal**: The Azure Portal is the primary interface for managing Azure resources. It provides a graphical interface to view and manage resources, including resource groups, virtual machines, storage accounts, and more.
    - **Pros**: User-friendly, comprehensive, and integrated with other Azure services.
    - **Cons**: May not provide the same level of detail as Resource Explorer for certain resources.

2. **Azure CLI**: The Azure Command-Line Interface (CLI) is a cross-platform command-line tool that allows you to manage Azure resources. It provides commands for creating, updating, and deleting resources, as well as querying resource information.
    - **Pros**: Scriptable, can be used in automation scripts, and provides detailed information about resources.
    - **Cons**: Requires knowledge of command-line syntax and may not be as user-friendly for those unfamiliar with CLI tools.

3. **Azure PowerShell**: Similar to Azure CLI, Azure PowerShell is a set of cmdlets for managing Azure resources from the command line. It is particularly useful for Windows users and integrates well with other PowerShell scripts and modules.
    - **Pros**: Powerful scripting capabilities, integrates with existing PowerShell scripts, and provides detailed resource information.
    - **Cons**: Requires knowledge of PowerShell syntax and may not be as user-friendly for those unfamiliar with PowerShell.

## Using Azure Portal to Explore Resources

The Azure Portal provides an interface for managing and exploring Azure resources. Here are some steps to explore resources using the Azure Portal:

1. Open [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) in [Azure Portal](https://portal.azure.com/) to view the resource. If intent is to modify resource, copy the resource uri with api version for modification.

2. Select the specific subscription, resource group, and then resource under 'Resources':

    ```text
    Subscriptions
        └───<subscription name>
            └───ResourceGroups
                └───<resource group name>
                    └───Resources
                        └───<resource name>
    ```

    ![Resource Explorer](../media/azure-resource-explorer-alternatives/resource-explorer-1.png)

3. If intent is to modify this resource, triple-click to copy the complete resource uri with api version from the read-only box to the right of `Open Blade` button. Example:

    ![Resource Explorer copy uri](../media/azure-resource-explorer-alternatives/resource-explorer-copy-resource-uri.png)

## Using Azure Portal to Update Resources

The Azure Portal can also be used to update resources. Here are some steps to update resources using the Azure Portal using the API Playground:

To use `API Playground` to modify the configuration of a resource, the resource uri with api version must be provided. Use the [Using Azure Portal to Explore Resources](#using-azure-portal-to-explore-resources) steps above to copy the resource uri with api version from Resource Explorer. Another option is to get the resource uri from the `Resource JSON` views that are available on resources in the Azure Portal. The `Resource JSON` view can be accessed by selecting the `JSON View` link on the top right side resource blade. This will open a new window with the JSON representation of the resource, including the resource uri and api version.

The resource uri format is as follows:

```text
/<subscription id>/resourceGroups/<resource group name>/providers/<resource provider>/<resource type>/<resource name>?api-version=<api version>
```

1. Navigate to [API Playground](https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground) in [Azure Portal](https://portal.azure.com/) and paste the copied resource uri with api version from Resource Explorer into the input box to the right of the HTTP Request Method.

2. Select `Execute` to view the configuration of the specified resource. Example:

    ![Resource Explorer](../media/azure-resource-explorer-alternatives/api-playground-get.png)

3. The `Response Body` will display the configuration of the resource similar to the Resource Explorer view. This response body can be copied and pasted into the `Request Body` above to modify the configuration. Example:

    ![Resource Explorer](../media/azure-resource-explorer-alternatives/api-playground-get-response.png)

4. Set the request method to `PUT` or `PATCH` depending on update type, select `Request Body`, and paste the copied response body. Modify the configuration as needed. Example:

    ![Resource Explorer](../media/azure-resource-explorer-alternatives/api-playground-patch.png)

5. Select `Execute` to modify the configuration. In the `Response Body`, verify the `Status Code` is '200' and the `provisioningState` is 'Updating' or 'Succeeded'. The provisioning status can be monitored in the [Azure Portal](https://portal.azure.com/) or by performing additional `Get` requests from [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) or [API Playground](https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground). Example:

    ![Resource Explorer](../media/azure-resource-explorer-alternatives/api-playground-patch-response.png)
