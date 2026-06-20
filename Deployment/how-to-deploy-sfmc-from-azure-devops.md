# How to Deploy Service Fabric Managed Clusters from Azure DevOps

> **Last validated:** March 2026

This guide covers deploying and managing Service Fabric Managed Cluster (SFMC) resources from Azure DevOps pipelines using `PowerShell@2`. These operations go through the Azure Resource Manager API (`management.azure.com`) and do **not** connect to the cluster directly - no Service Fabric server certificate issues apply.

For operations that require connecting to a cluster directly (health checks, SF SDK app deployment, `Connect-ServiceFabricCluster`), see [How to Connect to SFMC from Azure DevOps](how-to-connect-to-sfmc-from-azure-devops.md).

---

## What You Can Deploy This Way

| Resource | ARM Resource Type |
|----------|------------------|
| SFMC cluster (create/update) | `Microsoft.ServiceFabric/managedclusters` |
| Node types | `Microsoft.ServiceFabric/managedclusters/nodetypes` |
| SF applications | `Microsoft.ServiceFabric/managedclusters/applications` |
| SF application types | `Microsoft.ServiceFabric/managedclusters/applicationTypes` |
| SF services | `Microsoft.ServiceFabric/managedclusters/applications/services` |

All of these are standard ARM resources. You deploy them the same way you deploy any other Azure resource.

---

## Prerequisites

- **Azure service connection** in ADO (service principal with Contributor access to the resource group)
- **`Az.ServiceFabric`** and/or **`Az.Resources`** PowerShell modules on the agent
- Self-hosted agent or Microsoft-hosted agent (both work - no cert constraints)

---

## Option 1: Az.ServiceFabric Cmdlets (PowerShell@2)

The `Az.ServiceFabric` module provides dedicated cmdlets for SFMC resources. This is the most common approach.

### Create or Update an SFMC Cluster

```yaml
- task: AzurePowerShell@5
  displayName: 'Deploy SFMC cluster'
  inputs:
    azureSubscription: 'MyAzureServiceConnection'
    ScriptType: 'InlineScript'
    azurePowerShellVersion: 'LatestVersion'
    pwsh: false
    Inline: |
      $resourceGroup = "$(ResourceGroup)"
      $clusterName   = "$(ClusterName)"
      $location      = "$(Location)"

      # --- Create or update the managed cluster ---
      $cluster = New-AzServiceFabricManagedCluster `
        -ResourceGroupName $resourceGroup `
        -ClusterName $clusterName `
        -Location $location `
        -ClusterSku 'Standard' `
        -ClusterUpgradeMode 'Automatic' `
        -AdminPassword (ConvertTo-SecureString -String "$(AdminPassword)" -Force -AsPlainText) `
        -Verbose

      Write-Host "Cluster provisioning state: $($cluster.ProvisioningState)"
      Write-Host "Cluster FQDN: $($cluster.Fqdn)"
```

### Add a Node Type

```yaml
- task: AzurePowerShell@5
  displayName: 'Add node type'
  inputs:
    azureSubscription: 'MyAzureServiceConnection'
    ScriptType: 'InlineScript'
    azurePowerShellVersion: 'LatestVersion'
    pwsh: false
    Inline: |
      $nodeType = New-AzServiceFabricManagedNodeType `
        -ResourceGroupName "$(ResourceGroup)" `
        -ClusterName "$(ClusterName)" `
        -Name 'nt1' `
        -InstanceCount 5 `
        -VmSize 'Standard_D2s_v3' `
        -Primary `
        -Verbose

      Write-Host "Node type provisioning state: $($nodeType.ProvisioningState)"
```

### Register a Client Certificate

```yaml
- task: AzurePowerShell@5
  displayName: 'Add admin client certificate'
  inputs:
    azureSubscription: 'MyAzureServiceConnection'
    ScriptType: 'InlineScript'
    azurePowerShellVersion: 'LatestVersion'
    pwsh: false
    Inline: |
      # By thumbprint (self-signed certs)
      Add-AzServiceFabricManagedClusterClientCertificate `
        -ResourceGroupName "$(ResourceGroup)" `
        -ClusterName "$(ClusterName)" `
        -Thumbprint "$(ClientCertThumbprint)" `
        -Admin

      # Or by common name (CA-signed certs)
      # Add-AzServiceFabricManagedClusterClientCertificate `
      #   -ResourceGroupName "$(ResourceGroup)" `
      #   -ClusterName "$(ClusterName)" `
      #   -CommonName 'ado-sf-client-mycluster' `
      #   -IssuerThumbprint "$(IssuerThumbprint)" `
      #   -Admin
```

### Deploy an Application Type and Application

```yaml
- task: AzurePowerShell@5
  displayName: 'Deploy SF application via ARM'
  inputs:
    azureSubscription: 'MyAzureServiceConnection'
    ScriptType: 'InlineScript'
    azurePowerShellVersion: 'LatestVersion'
    pwsh: false
    Inline: |
      $resourceGroup = "$(ResourceGroup)"
      $clusterName   = "$(ClusterName)"

      # Register the application type (package must be in a blob store)
      New-AzServiceFabricManagedClusterApplicationType `
        -ResourceGroupName $resourceGroup `
        -ClusterName $clusterName `
        -Name 'MyAppType' `
        -Verbose

      # Create a specific version
      New-AzServiceFabricManagedClusterApplicationTypeVersion `
        -ResourceGroupName $resourceGroup `
        -ClusterName $clusterName `
        -Name 'MyAppType' `
        -Version '1.0.0' `
        -PackageUrl "$(AppPackageUrl)" `
        -Verbose

      # Create or update the application instance
      New-AzServiceFabricManagedClusterApplication `
        -ResourceGroupName $resourceGroup `
        -ClusterName $clusterName `
        -ApplicationTypeName 'MyAppType' `
        -ApplicationTypeVersion '1.0.0' `
        -Name 'MyApp' `
        -Verbose
```

---

## Option 2: ARM Template Deployment (PowerShell@2)

Use `New-AzResourceGroupDeployment` when you have ARM/Bicep templates for your SFMC resources.

```yaml
- task: AzurePowerShell@5
  displayName: 'Deploy SFMC via ARM template'
  inputs:
    azureSubscription: 'MyAzureServiceConnection'
    ScriptType: 'InlineScript'
    azurePowerShellVersion: 'LatestVersion'
    pwsh: false
    Inline: |
      New-AzResourceGroupDeployment `
        -ResourceGroupName "$(ResourceGroup)" `
        -TemplateFile "$(Build.SourcesDirectory)/templates/sfmc-cluster.json" `
        -TemplateParameterFile "$(Build.SourcesDirectory)/templates/sfmc-cluster.parameters.json" `
        -Verbose

      Write-Host "Deployment complete"
```

### Example ARM Template Snippet (SFMC Cluster + Application)

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "clusterName": { "type": "string" },
    "location": { "type": "string", "defaultValue": "[resourceGroup().location]" },
    "adminPassword": { "type": "securestring" },
    "appPackageUrl": { "type": "string" }
  },
  "resources": [
    {
      "type": "Microsoft.ServiceFabric/managedclusters",
      "apiVersion": "2024-04-01",
      "name": "[parameters('clusterName')]",
      "location": "[parameters('location')]",
      "sku": { "name": "Standard" },
      "properties": {
        "adminPassword": "[parameters('adminPassword')]",
        "clusterUpgradeMode": "Automatic",
        "clients": [
          {
            "isAdmin": true,
            "thumbprint": "<your-admin-client-cert-thumbprint>"
          }
        ]
      }
    },
    {
      "type": "Microsoft.ServiceFabric/managedclusters/nodetypes",
      "apiVersion": "2024-04-01",
      "name": "[concat(parameters('clusterName'), '/nt1')]",
      "location": "[parameters('location')]",
      "dependsOn": [
        "[resourceId('Microsoft.ServiceFabric/managedclusters', parameters('clusterName'))]"
      ],
      "properties": {
        "isPrimary": true,
        "vmSize": "Standard_D2s_v3",
        "vmInstanceCount": 5,
        "dataDiskSizeGB": 128
      }
    },
    {
      "type": "Microsoft.ServiceFabric/managedclusters/applicationTypes",
      "apiVersion": "2024-04-01",
      "name": "[concat(parameters('clusterName'), '/MyAppType')]",
      "location": "[parameters('location')]",
      "dependsOn": [
        "[resourceId('Microsoft.ServiceFabric/managedclusters', parameters('clusterName'))]"
      ]
    },
    {
      "type": "Microsoft.ServiceFabric/managedclusters/applicationTypes/versions",
      "apiVersion": "2024-04-01",
      "name": "[concat(parameters('clusterName'), '/MyAppType/1.0.0')]",
      "location": "[parameters('location')]",
      "dependsOn": [
        "[resourceId('Microsoft.ServiceFabric/managedclusters/applicationTypes', parameters('clusterName'), 'MyAppType')]"
      ],
      "properties": {
        "appPackageUrl": "[parameters('appPackageUrl')]"
      }
    },
    {
      "type": "Microsoft.ServiceFabric/managedclusters/applications",
      "apiVersion": "2024-04-01",
      "name": "[concat(parameters('clusterName'), '/MyApp')]",
      "location": "[parameters('location')]",
      "dependsOn": [
        "[resourceId('Microsoft.ServiceFabric/managedclusters/applicationTypes/versions', parameters('clusterName'), 'MyAppType', '1.0.0')]"
      ],
      "properties": {
        "typeName": "MyAppType",
        "typeVersion": "1.0.0"
      }
    }
  ]
}
```

---

## Option 3: OOB ARM Task

If you prefer the built-in ADO task instead of PowerShell, `AzureResourceManagerTemplateDeployment@3` also works. It uses the same ARM API path - no cert issues.

```yaml
- task: AzureResourceManagerTemplateDeployment@3
  displayName: 'Deploy SFMC via ARM task'
  inputs:
    deploymentScope: 'Resource Group'
    azureResourceManagerConnection: 'MyAzureServiceConnection'
    action: 'Create Or Update Resource Group'
    resourceGroupName: '$(ResourceGroup)'
    location: '$(Location)'
    templateLocation: 'Linked artifact'
    csmFile: '$(Build.SourcesDirectory)/templates/sfmc-cluster.json'
    csmParametersFile: '$(Build.SourcesDirectory)/templates/sfmc-cluster.parameters.json'
    deploymentMode: 'Incremental'
```

---

## Unified Pipeline Example: Deploy + Validate

Combine ARM deployment with SF SDK validation in a single pipeline. The deployment step uses ARM (no cert issue), then the validation step uses `Connect-ServiceFabricCluster` (requires `-ServerCertThumbprint` workaround).

```yaml
trigger:
  branches:
    include:
      - main

variables:
  ResourceGroup: 'mycluster-rg'
  ClusterName: 'mycluster'
  Location: 'eastus'
  ClientCertThumbprint: '<your-client-cert-thumbprint>'

stages:
- stage: Deploy
  jobs:
  - job: DeployCluster
    pool:
      name: 'MySelfHostedPool'      # or vmImage: 'windows-latest'
    steps:
    - task: AzurePowerShell@5
      displayName: 'Deploy SFMC cluster and app'
      inputs:
        azureSubscription: 'MyAzureServiceConnection'
        ScriptType: 'InlineScript'
        azurePowerShellVersion: 'LatestVersion'
        pwsh: false
        Inline: |
          New-AzResourceGroupDeployment `
            -ResourceGroupName "$(ResourceGroup)" `
            -TemplateFile "$(Build.SourcesDirectory)/templates/sfmc-cluster.json" `
            -TemplateParameterFile "$(Build.SourcesDirectory)/templates/sfmc-cluster.parameters.json" `
            -Verbose

- stage: Validate
  dependsOn: Deploy
  jobs:
  - job: ValidateCluster
    pool:
      name: 'MySelfHostedPool'
    steps:
    - task: PowerShell@2
      displayName: 'Validate cluster health via SF SDK'
      inputs:
        targetType: 'inline'
        pwsh: false
        script: |
          Import-Module Az.Resources
          Import-Module ServiceFabric

          $cluster = Get-AzResource -Name "$(ClusterName)" -ResourceGroupName "$(ResourceGroup)" `
                       -ResourceType 'Microsoft.ServiceFabric/managedclusters'
          $serverThumb = $cluster.Properties.clusterCertificateThumbprints
          $fqdn = $cluster.Properties.fqdn

          Connect-ServiceFabricCluster `
            -ConnectionEndpoint "${fqdn}:19000" `
            -X509Credential `
            -FindType FindByThumbprint `
            -FindValue "$(ClientCertThumbprint)" `
            -ServerCertThumbprint $serverThumb `
            -StoreLocation CurrentUser `
            -StoreName My

          $health = Get-ServiceFabricClusterHealth
          Write-Host "Cluster health: $($health.AggregatedHealthState)"
          if ($health.AggregatedHealthState -ne 'Ok') {
            Write-Warning "Cluster health is not Ok"
            $health | Format-List *
          }
```

> For details on the Validate step (auth options, NSG, troubleshooting), see [How to Connect to SFMC from Azure DevOps](how-to-connect-to-sfmc-from-azure-devops.md).

---

## Reference

- [How to Connect to SFMC from Azure DevOps](how-to-connect-to-sfmc-from-azure-devops.md) - SF SDK operations (`Connect-ServiceFabricCluster`)
- [Az.ServiceFabric module reference](https://learn.microsoft.com/powershell/module/az.servicefabric/)
- [SFMC ARM template reference](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/managedclusters)
- [Service Fabric managed cluster overview](https://learn.microsoft.com/azure/service-fabric/overview-managed-cluster)
