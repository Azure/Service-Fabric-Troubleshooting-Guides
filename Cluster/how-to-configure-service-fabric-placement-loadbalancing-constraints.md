# How to Configure Service Fabric Placement Properties and Loadbalancing Constraints

This article explains how to configure Service Fabric node placement properties and load balancing (PLB) constraints. PLB is a feature of Service Fabric Cluster Resource Manager (CRM) that allows you to control the placement of services and replicas on nodes in the cluster. Typically, this is done with default built-in node properties `NodeType` or `NodeName`, but you can also define custom constraints to optimize the placement of services and replicas based on specific requirements.

PLB is enabled at the cluster level and constraints are specified statically in application manifest or dynamically with powershell for the Service Fabric application and as tags on a node. Use the `PlacementConstraints` and `NodeProperties` elements to define constraints that control where services and replicas are placed in the cluster.

PLB can also be configured to constrain the placement of services and replicas based on node properties such as capacity, load, or other custom attributes. PLB constraints are used to ensure that services and replicas are distributed evenly across the cluster, or to optimize the placement of services and replicas based on specific requirements.

## PLB Constraint Alternatives

Here are some alternative options in Service Fabric that can be used to control the placement of services and replicas in the cluster. These include:

### Dynamic Node Tags

Dynamic node tags are used to assign custom properties to nodes in the cluster based on specific requirements. Node tags can be used to optimize the placement of services and replicas in the cluster by specifying the tag on nodes. These are dynamic only by design and are configured using PowerShell. Dynamic node tags however do not use expressions like PLB constraints. See [Introduction to dynamic node tags](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-node-tagging) for more information.

### Service Fabric Cluster Resource Manager

The Service Fabric Cluster Resource Manager (CRM) is responsible for balancing the placement of services and replicas in the cluster based on the constraints configured, metrics, and advanced placement rules. See [Service Fabric Cluster Resource Manager](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-balancing) for more information. CRM uses both default and custom metrics to determine the placement of services and replicas in the cluster. The default metrics are PrimaryCount, ReplicaCount, and Count of all services. CRM is also uses metrics from Resource Governance to determine the placement of services and replicas in the cluster.

### Resource Governance

Resource governance is a feature of Service Fabric that allows you to control the resource usage of services and replicas in the cluster. Resource governance can be used to optimize the placement of services and replicas based on resource usage, such as CPU and memory. See [Service Fabric Resource Governance](https://learn.microsoft.com/azure/service-fabric/service-fabric-resource-governance) for more information.

## Placement Design

After confirming PLB constraints is the best solution to implement that meets all requirements, the next step is to determine the key-value pairs for the node properties and placement constraints. For example, using `NodeType` as built-in property, or defining custom properties based on requirements. Determine if any expressions are needed. Having configurations with integer values or multiple possible values are examples. Ensure design allows for maintenance and upgrades of cluster resources using upgrade domains.

## Best Practices

- Use `NodeType` as it is a built-in property.
- Do not use `NodeName` as it is a single point of failure.
- Use custom properties if needed to optimize the placement of services and replicas based on specific requirements if default properties are not sufficient.
- Use the application manifest file to define placement constraints. This ensures that the configuration is not lost during application upgrades.
- Ensure design allows for maintenance and upgrades of cluster resources using upgrade domains.

## Process

1. Determine which PLB solution to use if any for your application.
2. Determine the key-value pairs for node properties and placement constraints.
3. If not using default properties, assign key-value pairs to node types in the cluster based on the custom properties.
4. Define `PlacementConstraints` in the application manifest file.
5. Deploy the application with the PLB constraints specified in the application manifest file.
6. Monitor the placement of services and replicas in the cluster to ensure that they are distributed according to the PLB constraints.

## Step by Step Guide

### Step 1: Determine which PLB solution to use if any for your application

Use resources provided in this article to determine if you need to use PLB for your application. If so, determine which solution to use. For example, if you need to optimize the placement of services and replicas based on resource usage, you can use Resource Governance. If you need to control the placement of services and replicas based on custom properties, you can use PLB constraints. If not PLB constraints for example dynamic tagging, then use steps provided for that feature instead of this document.

### Step 2: Determine the key-value pairs for node type properties and placement constraints

Determine the key-value pairs for node type properties and placement constraints based on your requirements. For example, you can use `NodeType` as a built-in property, or define custom properties such as `HasSSD`, `IsHighMemory`, etc.

### Step 3: Assign node properties to node type in the cluster based on the custom properties

Using ARM template or PowerShell, assign the key-value pairs to the node types in the cluster. This can be done using the `placementProperties` element in the ARM template or using PowerShell commands to update the node properties. See [Example ARM Template](#example-arm-template) and [PowerShell Commands](#powershell-commands) below for more information. This will initiate a cluster upgrade and the nodes Service Fabric services will be restarted.

### Step 4: Define `PlacementConstraints` in the application manifest file

Update the application manifest file to include the placement constraints using the `PlacementConstraints` element. This can be done using the `PlacementConstraint` element in the application manifest file. See [Example ApplicationManifest.xml](#example-applicationmanifestxml) and [Placement Expression Examples](#placement-expression-examples) below for more information.

### Step 5: Deploy the application with the PLB constraints specified in the application manifest file or dynamically using PowerShell

Deploy the application using the updated application manifest file. This can be done using PowerShell commands or using the Service Fabric SDK. See [Create a new service with placement constraints](#create-a-new-service-with-placement-constraints) and [Update an existing service with placement constraints](#update-an-existing-service-with-placement-constraints) below for more information.

### Step 6: Monitor the placement of services and replicas in the cluster

After deploying the application, monitor the placement of services and replicas in the cluster to ensure that they are distributed according to the PLB constraints. This can be done using PowerShell commands or Service Fabric Explorer (SFX). See [Troubleshooting](#troubleshooting) below for troubleshooting information if having issues.

## PowerShell Commands

To configure PLB constraints dynamically using PowerShell, you can use the following commands:

### Connect to cluster

From an admin machine with [Service Fabric SDK](https://learn.microsoft.com/azure/service-fabric/service-fabric-get-started) installed, open a [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (pwsh.exe) window and run the following commands to connect to the Service Fabric cluster. These commands do require PowerShell 6+, Azure 'Az.Accounts', and 'Az.Resources' modules to be installed. [Connect-ServiceFabricCluster](https://learn.microsoft.com/powershell/module/servicefabric/connect-servicefabriccluster) cmdlet is used to connect to the cluster and has many options. Refer to online documentation and [Connecting to secure clusters with PowerShell](Connecting%20to%20secure%20clusters%20with%20PowerShell.md):

```powershell
Import-Module ServiceFabric
# Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser
# Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser
Import-Module Az.Accounts
Import-Module Az.Resources

# Connect to the cluster has many options, here is an example using X509 certificate
Connect-ServiceFabricCluster -ConnectionEndpoint "mycluster.westus.cloudapp.azure.com:19000" `
    -X509Credential `
    -ServerCertThumbprint "<server thumbprint>" `
    -FindType FindByThumbprint `
    -FindValue "<client thumbprint>"

Connect-AzAccount
```

### Add / Update / Remove key-value pairs for node properties on node types

```powershell
#Requires -PSEdition Core
# set parameters
$resourceGroupName = "myResourceGroup"
$clusterName = "myCluster"
$nodeTypeName = "NodeType0"
$key = "HasSSD"
$value = "true"
$addOrRemove = "add" # or "remove"
$jsonFile = "$pwd\cluster.json"

$resource = Get-AzResource -Name $clusterName `
    -ResourceGroupName $resourceGroupName `
    -ResourceType 'microsoft.servicefabric/clusters'

Export-AzResourceGroup -ResourceGroupName $resourceGroupName `
    -Resource $resource.Id `
    -Path $jsonFile `
    -SkipAllParameterization `
    -Force

$cluster = ConvertFrom-Json -AsHashTable (Get-Content -Raw $jsonFile)

foreach ($nodeType in $cluster.resources.properties.nodeTypes) {
    if ($nodeType.name -ine $nodeTypeName) {
        Write-Host "Skipping nodetype $($nodeType.name) does not match $nodeTypeName"
        continue 
    }
    $found = $true
    if ($addOrRemove -ieq "add") {
        if ($nodeType.placementProperties -eq $null) {
            Write-Host "Setting placement properties for node type $nodeTypeName"
            $nodeType.placementProperties = @{$key = $value }
        }
        elseif ($nodeType.placementProperties.ContainsKey($key)) {
            Write-Host "Updating placement properties for node type $nodeTypeName"
            $nodeType.placementProperties.$key = $value
        }
        else {
            Write-Host "Adding placement properties for node type $nodeTypeName"
            $nodeType.placementProperties.Add($key, $value)
        }
    }
    elseif ($addOrRemove -ieq "remove") {
        if ($nodeType.placementProperties -ne $null `
                -and $nodeType.placementProperties.ContainsKey($key)) {
            Write-Host "Removing placement properties for node type $nodeTypeName"
            $nodeType.placementProperties.Remove($key)
        }
        else {
            Write-Host "Key not found for $nodeTypeName"
        }
    }
}

if ($found) {
    Write-Host "Updating cluster $clusterName in resource group $resourceGroupName"
    $cluster | ConvertTo-Json -Depth 100 | Out-File -Path $jsonFile -Force
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
        -TemplateFile $jsonFile `
        -Mode Incremental `
        -Verbose
}
else {
    Write-Host "Node type $nodeTypeName not found in cluster $clusterName"
}
```

### Add / Update service with placement constraints

To configure PLB constraints dynamically using PowerShell, you can use the following commands:

#### Create a new service with placement constraints

```powershell
New-ServiceFabricService -ApplicationName $applicationName `
  -ServiceName $serviceName `
  -ServiceTypeName $serviceType `
  -Stateful -MinReplicaSetSize 3 `
  -TargetReplicaSetSize 3 `
  -PartitionSchemeSingleton `
  -PlacementConstraint "HasSSD == true && SomeProperty >= 4"
```

#### Update an existing service with placement constraints

```powershell
Update-ServiceFabricService -ServiceName $serviceName `
  -Stateful `
  -PlacementConstraint "HasSSD == true && SomeProperty >= 4"
```

## Example ApplicationManifest.xml

To configure PLB constraints statically in the application manifest file `<PlacementConstraints>` child element is used. See [Describe an application in ApplicationManifest.xml](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-manifests#describe-an-application-in-applicationmanifestxml) and the following example:

```xml
<?xml version="1.0" encoding="utf-8"?>
<ApplicationManifest xmlns:xsd="https://www.w3.org/2001/XMLSchema" xmlns:xsi="https://www.w3.org/2001/XMLSchema-instance" ApplicationTypeName="VotingType" ApplicationTypeVersion="1.0.0" xmlns="http://schemas.microsoft.com/2011/01/fabric">
...
   <Service Name="VotingWeb" ServicePackageActivationMode="ExclusiveProcess">
      <StatelessService ServiceTypeName="VotingWebType" InstanceCount="[VotingWeb_InstanceCount]">
        <SingletonPartition />
         <PlacementConstraints>(NodeType==NodeType0)</PlacementConstraints>
      </StatelessService>
    </Service>
  </DefaultServices>
</ApplicationManifest>
```

## Example ARM Template

To configure node properties using an ARM template, you can use the following example:

### Define node properties

```json
{
    "apiVersion": "2019-03-01",
    "name": "[parameters('clusterName')]",
    "type": "Microsoft.ServiceFabric/clusters",
    "location": "[parameters('location')]",
    "properties": {
        "reliabilityLevel": "Bronze",
        "nodeTypes": [
            {
                "name": "NodeType0",
                "placementProperties": {
                    "HasSSD": "true"
                }
            },
            {
                "name": "NodeType1",
                "placementProperties": {
                    "HasSSD": "false"
                }
            }
        ]
    }
}
```

### Define service with placement constraints

See [Microsoft.ServiceFabric clusters/applications](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/clusters/applications/services?pivots=deployment-language-arm-template)

```json
{
    "apiVersion": "2020-03-01",
    "type": "Microsoft.ServiceFabric/clusters/applications/services",
    "name": "[concat(parameters('clusterName'), '/', parameters('applicationName'), '/', parameters('serviceName'))]",
    "location": "[variables('clusterLocation')]",
    "dependsOn": [
        "[concat('Microsoft.ServiceFabric/clusters/', parameters('clusterName'), '/applications/', parameters('applicationName'))]"
    ],
    "properties": {
        "provisioningState": "Default",
        "serviceKind": "Stateless",
        "serviceTypeName": "[parameters('serviceTypeName')]",
        "instanceCount": "-1",
        "partitionDescription": {
            "partitionScheme": "Singleton"
        },
        "placementConstraints": "(HasSSD == true && NodeType==NodeType0)", // todo: confirm this
        "serviceLoadMetrics": [],
        "servicePlacementPolicies": [],
        "defaultMoveCost": ""
    }
}
```

### Placement Expression operators

[Placement Constraints and node property syntax](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-cluster-description#placement-constraints-and-node-property-syntax)

Expressions for placement constraints and node properties are specified using the following operators:

- `==` (equals)
- `!=` (not equals)
- `>` (greater than)
- `<` (less than)
- `>=` (greater than or equal to)
- `<=` (less than or equal to)
- `&&` (logical AND)
- `||` (logical OR)
- `!` (logical NOT)
- `(` and `)` (parentheses for grouping)

### Placement Expression Examples

- `NodeType == "FrontEnd"`
- `NodeType != "BackEnd"`
- `NodeType == "FrontEnd" && NodeName == "Node1"`
- `NodeType == "FrontEnd" || NodeName == "Node1"`
- `Value > 10`
- `Value <= 10`

## Troubleshooting

### Service Fabric Explorer (SFX)

Use Service Fabric Explorer (SFX) to monitor and manage Service Fabric clusters. You can use SFX to view the status of services and replicas in the cluster, as well as the placement of services and replicas based on PLB constraints.

- Open SFX in a browser by navigating to `https://<cluster-name>:19080/Explorer`.
- Click on the "Applications" to view the list of applications deployed in the cluster.
- Click on the application name to view the details of the application.
- Select 'Manifest' to view the application manifest file and the placement constraints defined in the file.
- Ensure that the placement constraints are correctly defined and that the services and replicas are distributed according to the constraints.

### Example PowerShell Commands

- [`Connect-ServiceFabricCluster`](https://learn.microsoft.com/powershell/module/servicefabric/connect-servicefabriccluster?view=azureservicefabricps) - Connects to the Service Fabric cluster.
- [`Get-ServiceFabricClusterManifest`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricclustermanifest?view=azureservicefabricps) - Retrieves the cluster manifest for the Service Fabric cluster.
- [`Get-ServiceFabricApplicationManifest`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricapplicationmanifest?view=azureservicefabricps) - Retrieves the application manifest for the Service Fabric application.
- [`Get-ServiceFabricNode`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricnode?view=azureservicefabricps) - Retrieves information about the nodes in the Service Fabric cluster.
- [`Get-ServiceFabricDeployedApplication`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricdeployedapplication?view=azureservicefabricps) - Retrieves information about the applications deployed in the Service Fabric cluster on a node.
- [`Get-ServiceFabricService -Application fabric:/<Application Name>`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricservice?view=azureservicefabricps) - Retrieves information about the services deployed in the Service Fabric cluster.
- [`Get-ServiceFabricReplica`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricreplica?view=azureservicefabricps) - Retrieves information about the replicas deployed in the Service Fabric cluster.

## Reference

- [Node properties and placement constraints](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-cluster-description#node-properties-and-placement-constraints)

- [Describe an application in ApplicationManifest.xml](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-manifests#describe-an-application-in-applicationmanifestxml)

- [Service Fabric Cluster Resource Manager](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-balancing)

- [Introduction to dynamic node tags](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-node-tagging)

- [Advanced Placement Properties](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-advanced-placement-rules-placement-policies)

- [Service Fabric Service Model Schema Elements](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#placementconstraints-element)
