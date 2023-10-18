# How to configure Azure Devops for Service Fabric ARM template deployments

This guide documents the process to configure Azure Devops (ADO) for Service Fabric ARM template deployments. This can be used for both cluster and application deployments. This is valid for both unmanaged and managed clusters deployments.

For Service Fabric Managed Cluster deployments not using ARM templates, see [How to configure Azure Devops for Service Fabric Managed Cluster](./how-to-configure-azure-devops-for-service-fabric-managed-cluster.md). For Service Fabric Cluster deployments not using ARM templates, see [How to configure Azure Devops for Service Fabric Cluster](./how-to-configure-azure-devops-for-service-fabric-cluster.md).

## Requirements

- Existing ARM template for cluster or application deployment. See [Service Fabric ARM templates](#service-fabric-arm-templates) for more information.

- Existing Azure Devops project.

- For Service Fabric application deployments, an accessible URL location for the application package. This can be a public URL or a URL that is accessible from the pipeline.

- Access to Azure Resource Manager (ARM) endpoint from Azure Devops.

<!-- todo -->

## Process

- Open the Azure Devops project and create a [New YAML pipeline](#new-yaml-pipeline).
- Add [ARM template deployment task](#add-arm-template-deployment-task) to the pipeline.
- [Test](#testing) the pipeline.
<!-- todo -->

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

## Azure Devops YAML pipeline

### New YAML pipeline

1. Open the Azure Devops project and create a new pipeline.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline.png)

1. Select the repository where the ARM template is located.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-repo.png)

1. Configure the pipeline to use 'Starter pipeline' YAML file.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-yaml.png)

1. Review the pipeline YAML file.

    ![](/media/how-to-configure-azure-devops-for-service-fabric-arm-deployments/ado-new-pipeline-yaml-review.png)

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


#### Template

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
    - master

    pool:
    vmImage: windows-latest

    steps:
    - task: AzureResourceManagerTemplateDeployment@3
      inputs:
        deploymentScope: 'Resource Group'
        azureResourceManagerConnection: '<service connection name>'
        subscriptionId: '<subscription id>'
        action: 'Create Or Update Resource Group'
        resourceGroupName: '<resource group name>'
        location: '<location>'
        templateLocation: 'URL of the file'
        csmFileLink: '<url to arm template>'
        csmParametersFileLink: '<url to arm template parameters>'
        deploymentMode: 'Incremental'
    ```

1. Add any additional tasks to the pipeline as needed and save.

## Testing

### Template validation

Validate the ARM template using Azure PowerShell.

```powershell
Test-AzResourceGroupDeployment -ResourceGroupName "myresourcegroup" `
    -TemplateFile .\azuredeploy.json `
    -TemplateParameterFile .\azuredeploy.parameters.json `
    -Debug
```

### Devops pipeline validation


## Troubleshooting

Test network connectivity. Add a powershell task to pipeline to run 'test-netconnection' command to cluster endpoint, providing tcp port. Default port is 19000.

Example:
  
  ```yaml
  - powershell: |
      $psversiontable
      [environment]::getenvironmentvariables().getenumerator()|sort Name
      $publicIp = (Invoke-RestMethod https://ipinfo.io/json).ip
      write-host "---`r`ncurrent public ip:$publicIp" -ForegroundColor Green
      write-host "test-netconnection $env:clusterEndpoint -p $env:clusterPort"
      $result = test-netconnection $env:clusterEndpoint -p $env:clusterPort
      write-host "test net connection result: $($result | fl * | out-string)"
      if(!($result.TcpTestSucceeded)) { throw }
    errorActionPreference: stop
    displayName: "PowerShell Troubleshooting Script"
    failOnStderr: true
    ignoreLASTEXITCODE: false
    env:  
      clusterPort: 19000
      clusterEndpoint: xxxxxx.xxxxx.cloudapp.azure.com
  ```


<!-- tsg source info reference -->
ado arm deployment task:
https://github.com/microsoft/azure-pipelines-tasks/blob/master/Tasks/AzureResourceManagerTemplateDeploymentV3/README.md

arm cluster deployment:
https://learn.microsoft.com/en-us/azure/service-fabric/quickstart-cluster-template

arm application deployment:
https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-application-arm-resource