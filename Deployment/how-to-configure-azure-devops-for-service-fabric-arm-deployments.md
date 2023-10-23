# How to configure Azure Devops for Service Fabric ARM template deployments

This guide documents the process to configure Azure Devops (ADO) for Service Fabric ARM template deployments. This can be used for both cluster and application deployments and is considered a best practice. This process is valid for both Service Fabric Cluster and Service Fabric Managed Cluster deployments. ARM ADO deployments do not require cluster certificate configuration, cluster connection configuration, or Network Security Group (NSG) configuration. For this reason, ADO ARM deployments support parallel deployments, which can be used to deploy multiple clusters or applications at the same time from same deployment agent.

For Service Fabric Managed Cluster deployments not using ARM templates, see [How to configure Azure Devops for Service Fabric Managed Cluster](./how-to-configure-azure-devops-for-service-fabric-managed-cluster.md). For Service Fabric Cluster deployments not using ARM templates, see [How to configure Azure Devops for Service Fabric Cluster](./how-to-configure-azure-devops-for-service-fabric-cluster.md).

## Requirements

- ARM template for cluster or application deployment. See [Service Fabric ARM templates](#service-fabric-arm-templates) for more information.
- Azure Devops project.
- For Service Fabric application deployments:
  - Sfpkg package for the application.
  - Accessible URL location for the application package. This can be a public URL or a URL that is accessible from the pipeline.

## Process

- Create or use an existing [ARM template](#service-fabric-arm-templates) for cluster or application deployment.
- For Service Fabric application deployments, create an sfpkg package for the application and upload to an accessible URL location.
- Create or use an existing [Azure Devops project](#requirements).
- In ADO create a [New YAML pipeline](#new-yaml-pipeline).
- Add [ARM template deployment task](#add-arm-template-deployment-task) to the pipeline.
- Deploy the pipeline.
- Verify / [Troubleshoot](#troubleshooting) the deployment.

## Service Fabric ARM templates

### Service Fabric Cluster ARM template

There are different options available to create an ARM template for a Service Fabric cluster. ['Microsoft.ServiceFabric/clusters'](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/clusters?pivots=deployment-language-arm-template) is the ARM resource used for cluster deployment. The following are some of the options available.

- Learn Documentation: To create a Service Fabric cluster using an ARM template, see [Create a Service Fabric cluster Resource Manager template](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-creation-create-template).

- Azure Samples Service Fabric Cluster Templates: https://github.com/Azure-Samples/service-fabric-cluster-templates

- Azure Portal: See [Create a Service Fabric cluster using the Azure portal](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-creation-via-portal). Using [Azure portal](https://ms.portal.azure.com/#create/Microsoft.ServiceFabricCluster) will create a Service Fabric cluster ARM template that can be downloaded and used for future deployments. This template will include the 'Microsoft.ServiceFabric/clusters' resource and all other resources that were created as part of the cluster deployment. After configuration of template settings, instead of deploying the template, select 'Download a  template for automation' link.

    > **Note:**
    > This template should be saved and not deployed.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/arm-portal-new-cluster-save-template.png)

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/arm-portal-new-cluster-download-template.png)

### Service Fabric Managed Cluster ARM template

For Service Fabric Managed Cluster templates, similar to Service Fabric Cluster templates, there are different options available to create an ARM template for a Service Fabric managed cluster. However, the ARM resource used for managed cluster deployment is ['Microsoft.ServiceFabric/managedClusters'](https://docs.microsoft.com/en-us/azure/templates/microsoft.servicefabric/managedclusters?pivots=deployment-language-arm-template). Managed clusters can also use a template generated from an existing cluster. The following are some of the options available.

- Existing cluster: To create a Service Fabric managed cluster using an ARM template, see [How to Export Service Fabric Managed Cluster Configuration](../how-to-export-service-fabric-managed-cluster-configuration.md).

- Learn Documentation:

- Azure Samples Service Fabric Cluster Templates: https://github.com/Azure-Samples/service-fabric-cluster-templates

- Azure Portal: See [Create a Service Fabric cluster using the Azure portal](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-creation-via-portal). Using [Azure portal](https://ms.portal.azure.com/#create/Microsoft.ServiceFabricCluster) will create a Service Fabric cluster ARM template that can be downloaded and used for future deployments. This template will include the 'Microsoft.ServiceFabric/clusters' resource and all other resources that were created as part of the cluster deployment. After configuration of template settings, instead of deploying the template, select 'Download a  template for automation' link.

    > **Note:**
    > This template should be saved and not deployed.

### Service Fabric Application ARM template

There are different options available to create an ARM template for a Service Fabric application. ['Microsoft.ServiceFabric/clusters/applications'](https://docs.microsoft.com/en-us/azure/templates/microsoft.servicefabric/clusters/applications?pivots=deployment-language-arm-template) is the ARM resource used for application deployment.

#### Service Fabric Application Sfpkg Package

To create an sfpkg package for a Service Fabric application, see [Package an application](https://learn.microsoft.com/azure/service-fabric/service-fabric-package-apps). After creation, upload the sfpkg package to the sfpkg package URL being used as a parameter for the ARM template deployment task.

## Azure Devops YAML pipeline

### New YAML pipeline

1. Open the Azure Devops project and create a new pipeline.

    ![ado new pipeline](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline.png)

1. Select the repository where the ARM template is located.

    ![ado new pipeline repo](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-repo.png)

1. Configure the pipeline to use 'Starter pipeline' YAML file.

    ![ado new pipeline yaml](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-yaml.png)

1. Review the pipeline YAML file.

    ![ado new pipeline yaml review](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-yaml-review.png)

    - set the 'pool' 'vmImage:' to 'windows-latest' and remove all lines below 'steps:'.

    ```yaml
        # Starter pipeline
        # Start with a minimal pipeline that you can customize to build and deploy your code.
        # Add steps that build, run tests, deploy, and more:
        # https://aka.ms/yaml

        trigger:
        - master

        pool:
        vmImage: windows-latest

        steps:
    ```

1. Save the pipeline.

### Add ARM template deployment task

Below adds an ARM template deployment. All variables for this task are listed in [AzureResourceManagerTemplateDeployment@ - ARM template deployment task](https://learn.microsoft.com/azure/devops/pipelines/tasks/reference/azure-resource-manager-template-deployment-v3?view=azure-pipelines).

#### Azure Details

1. Open the Azure Devops project and select the pipeline to update.

1. Select 'Show assistant' in top right to open the pipeline assistant.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-assistant.png)

1. Search for 'ARM template deployment' and select.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-assistant-arm.png)

1. Select 'Resource group' for 'Deployment scope'.

1. Select existing Service connection for 'Azure Resource Manager connection' or select the Subscription Name to create a new connection. If creating a new connection, select 'Authorize' to create. The same connection can be created / managed in the projects 'Service connections' settings.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-assistant-arm-connection.png)

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-assistant-arm-service-connection.png)

1. Select Subscription Name for 'Subscription'.

1. Leave the default 'Action' of 'Create or update resource group'.

1. Select the 'Resource group' to deploy to.

1. Select the 'Location' to deploy to.

#### Cluster Template

1. In this example, for 'Template Location' select 'URL of the existing template file'.

1. For 'Template link', enter the URL of the ARM template to deploy. This can be a public URL or a URL that is accessible from the pipeline.

    - Example: https://raw.githubusercontent.com/Azure-Samples/service-fabric-cluster-templates/master/5-VM-Windows-1-NodeTypes-Secure-NSG/azuredeploy.json

1. For 'Template parameters', enter the parameters for the ARM template. This can be a public URL or a URL that is accessible from the pipeline.

    - Example: https://raw.githubusercontent.com/Azure-Samples/service-fabric-cluster-templates/master/5-VM-Windows-1-NodeTypes-Secure-NSG/azuredeploy.parameters.json

1. Leave the default 'Deployment mode' of 'Incremental'.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-assistant-arm-template-settings.png)

1. When complete, select 'Add' to add the task to the pipeline.

    ```yaml
    trigger:
    - main

    pool:
      vmImage: windows-latest

    variables:
      System.Debug: true
      resource_group_name: sf-test-cluster
      cluster_name: sf-test-cluster
      #deployment_name: $[format('{1}-{0:yyyy}{0:MM}{0:dd}-{0:HH}{0:mm}{0:ss}', pipeline.startTime, variables['cluster_name'])]
      location: eastus
      template_url: https://raw.githubusercontent.com/Azure-Samples/service-fabric-cluster-templates/master/5-VM-Windows-1-NodeTypes-Secure-NSG/azuredeploy.json
      template_parameters_url: https://raw.githubusercontent.com/Azure-Samples/service-fabric-cluster-templates/master/5-VM-Windows-1-NodeTypes-Secure-NSG/azuredeploy.parameters.json
      arm_connection_name: ARM service connection
      subscription_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # or store in azure pipeline variable
      admin_username: cloudadmin # or store in azure pipeline variable
      admin_password: password # or store in azure pipeline variable
      certificate_thumbprint: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx # or store in azure pipeline variable
      source_vault: /subscriptions/$(subscription_id)/resourceGroups/<resource group>/providers/Microsoft.KeyVault/vaults/<vault name> # or store in azure pipeline variable

    steps:
    - task: AzureResourceManagerTemplateDeployment@3
      inputs:
        deploymentScope: 'Resource Group'
        azureResourceManagerConnection: $(arm_connection_name)
        subscriptionId: $(subscription_id)
        action: 'Create Or Update Resource Group'
        resourceGroupName: $(resource_group_name)
        location: $(location)
        templateLocation: 'URL of the file'
        csmFileLink: $(template_url)
        csmParametersFileLink: $(template_parameters_url)
        overrideParameters: |
            -clusterLocation $(location)
            -clusterName $(cluster_name)
            -adminUserName $(admin_username)
            -adminPassword (ConvertTo-SecureString -String '$(admin_password)' -AsPlainText -Force)
            -certificateThumbprint $(certificate_thumbprint)
            -sourceVaultValue $(source_vault)
        deploymentMode: 'Incremental'
        deploymentName: $(deployment_name)
    ```

1. Add any pipeline variables and tasks as needed and save.

#### Cluster Application Template

1. In this example, for 'Template Location' select 'URL of the existing template file'.

1. For 'Template link', enter the URL of the ARM template to deploy. This can be a public URL or a URL that is accessible from the pipeline.

    - Example: https://raw.githubusercontent.com/Azure-Samples/service-fabric-dotnet-quickstart/master/ARM/UserApp.json

1. For 'Template parameters', enter the parameters for the ARM template. This can be a public URL or a URL that is accessible from the pipeline.

    - Example: https://raw.githubusercontent.com/Azure-Samples/service-fabric-dotnet-quickstart/master/ARM/UserApp.Parameters.json

1. Leave the default 'Deployment mode' of 'Incremental'.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-assistant-arm-template-settings.png)

1. When complete, select 'Add' to add the task to the pipeline.

    ```yaml
    trigger:
    - main

    pool:
      vmImage: windows-latest

    variables:
      System.Debug: true
      resource_group_name: sf-test-cluster
      cluster_name: sf-test-cluster
      #deployment_name: $[format('{1}-{0:yyyy}{0:MM}{0:dd}-{0:HH}{0:mm}{0:ss}', pipeline.startTime, variables['cluster_name'])]
      location: eastus
      template_url: https://raw.githubusercontent.com/Azure-Samples/service-fabric-dotnet-quickstart/master/ARM/UserApp.json
      template_parameters_url: https://raw.githubusercontent.com/Azure-Samples/service-fabric-dotnet-quickstart/master/ARM/UserApp.Parameters.json
      package_url: https://raw.githubusercontent.com/<owner>/<repository>/master/serviceFabric/sfpackages/Voting.1.0.0.sfpkg
      arm_connection_name: ARM service connection
      subscription_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # or store in azure pipeline variable

    steps:
    - task: AzureResourceManagerTemplateDeployment@3
      inputs:
        deploymentScope: 'Resource Group'
        azureResourceManagerConnection: $(arm_connection_name)
        subscriptionId: $(subscription_id)
        action: 'Create Or Update Resource Group'
        resourceGroupName: $(resource_group_name)
        location: $(location)
        templateLocation: 'URL of the file'
        csmFileLink: $(template_url)
        csmParametersFileLink: $(template_parameters_url)
        overrideParameters: '-appPackageUrl $(package_url) -clusterName $(cluster_name)'
        deploymentMode: 'Incremental'
        deploymentName: $(deployment_name)
    ```

1. Add any pipeline variables and tasks as needed and save.

### First Run

Run the pipeline manually and validate the deployment. There may be one-time configuration settings or approvals required.

## Troubleshooting

### Template validation with PowerShell

Validate the ARM template using Azure PowerShell [Test-AzResourceGroupDeployment](https://learn.microsoft.com/powershell/module/az.resources/test-azresourcegroupdeployment) cmdlet.

```powershell
Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile .\azuredeploy.json `
    -TemplateParameterFile .\azuredeploy.parameters.json
```

### Template deployment with PowerShell

Deploy the ARM template using Azure PowerShell [New-AzResourceGroupDeployment](https://learn.microsoft.com/powershell/module/az.resources/new-azresourcegroupdeployment) cmdlet.

```powershell
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -DeploymentDebugLogLevel All `
    -TemplateFile .\azuredeploy.json `
    -TemplateParameterFile .\azuredeploy.parameters.json `
    -Verbose `
    -Debug
```

### Enable debug logging

Enable debug logging for the pipeline to view additional details in log output for the tasks in pipeline.

```yaml
variables:
  System.Debug: true
```
