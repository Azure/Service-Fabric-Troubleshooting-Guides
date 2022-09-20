# Azure Service Fabric cluster rebuild (minimal approach)

If your resource group contains resources which cannot easily redeployed by applying an ARM template, then a selectively deletion might help you to achieve a quicker deployment.

A fast rebuild of an Azure Service Fabric cluster might be needed in the cases for example where the latest template deployment contained wrong data or unsupported configurations. In those cases the fastest mitigation can be to rebuild the cluster.

Quickly explained, this approach recommends to delete specific Azure resources manually and reapply the ARM template with old or corrected configuration. The Azure Service Fabric (ASF) cluster resource including all associated Azure Virtual Machine Scale Sets (VMSS) must be removed.

## Pre-requisites

Please have a well maintained and tested ARM template handy which can create the resources in the desired form.

The PowerShell CMDlet [New-AzResourceGroupDeployment](https://docs.microsoft.com/powershell/module/az.resources/new-azresourcegroupdeployment) needs to be executed with the parameter DeploymentMode=Incremental.

> :warning:
> Exporting the ARM template from the Azure portal via "Export template" function might be not sufficient as it cannot contain secrets and dynamically changed values. 

## Step by Step

1. Remove ASF cluster including all associated VMSS

    ```powershell
    Connect-AzAccount
    Set-AzContext -SubscriptionId <guid>
    $resourceGroupName = "<name of the Azure Resource Group>"
    Get-AzResource -ResourceGroupName $resourceGroupName | ft
    
    Remove-AzResource -ResourceName "<name of the Azure Service Fabric resource>" -ResourceType "Microsoft.ServiceFabric/clusters" -ResourceGroupName $resourceGroupName -Force
    
    Remove-AzVmss -ResourceGroupName $resourceGroupName -VMScaleSetName "<name of the Azure Virtual Machine Scale Set>"
    ```

    Documentation:
    https://docs.microsoft.com/azure/service-fabric/service-fabric-tutorial-delete-cluster#selectively-delete-the-cluster-resource-and-the-associated-resources
    
2. Deploy the ARM template to create ASF cluster and VMSS

    Apply the latest version of your ARM template with [New-AzResourceGroupDeployment](https://docs.microsoft.com/powershell/module/az.resources/new-azresourcegroupdeployment).

