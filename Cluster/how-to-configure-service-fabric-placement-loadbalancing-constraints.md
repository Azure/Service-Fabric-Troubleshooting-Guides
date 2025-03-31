# todo: use 'placement properties' are on the node type 'placement constraints' use the 'placement properties'

# todo: add best practices

    - not using nodename (single point of failure)
    - nodetype is preferred
    - application manifest is preferred as configuration will not be lost during application upgrade

# How to Configure Service Fabric Placement and Load Balancing Constraints

This article explains how to configure Service Fabric placement and load balancing (PLB) constraints. It is based on the official documentation and provides a step-by-step guide with examples.

PLB is a feature of Service Fabric that allows you to control the placement of services and replicas on nodes in the cluster. Typically, this is done with default built-in node properties `NodeType` or `NodeName`, but you can also define custom constraints to optimize the placement of services and replicas based on specific requirements.

PLB is enabled at the cluster level and constraints are specified statically in application manifest or dynamically with powershell for the Service Fabric application and as tags on a node. Use the `PlacementConstraints` and `NodeProperties` elements to define constraints that control where services and replicas are placed in the cluster.

PLB can be configured to constrain the placement of services and replicas based on node properties such as capacity, load, or other custom attributes. PLB constraints are used to ensure that services and replicas are distributed evenly across the cluster, or to optimize the placement of services and replicas based on specific requirements. PLB constraints are configured by specifying key-value pairs for node properties and placement constraints in the application manifest file.

## PLB Alternatives

Related to PLB, there are other features and concepts in Service Fabric that can be used to control the placement of services and replicas in the cluster. These include:

### Dynamic Node Tags

Dynamic node tags are used to assign custom properties to nodes in the cluster based on specific requirements. Node tags can be used to optimize the placement of services and replicas in the cluster by specifying constraints based on the custom properties assigned to nodes. These are dynamic only by design and are configured using PowerShell. Dynamic node tags however do not use expressions like PLB constraints. See [Introduction to dynamic node tags](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-node-tagging) for more information.

### Service Fabric Cluster Resource Manager

The Service Fabric Cluster Resource Manager is responsible for balancing the placement of services and replicas in the cluster based on the constraints specified in the application manifest file. The Cluster Resource Manager uses the Placement and Load Balancing (PLB) service to optimize the placement of services and replicas in the cluster based on the constraints specified in the application manifest file. See [Service Fabric Cluster Resource Manager](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-balancing) for more information. CRM is a metrics based cluster level balancing mechanism.

## Placement Design

Determining the key-value pairs for the node properties and placement constraints is the first step in configuring PLB constraints. You can use `NodeType` or `NodeName` as built-in properties, or define custom properties based on your requirements.

Resource capacity, load, or other custom attributes can be used as node properties to optimize the placement of services and replicas in the cluster. You can define custom properties in the application manifest file and assign values to nodes in the cluster.

## Process

1. Determine the key-value pairs for node properties and placement constraints.
2. If not using default properties, assign values to nodes in the cluster based on the custom properties.
3. Define expression using node properties in the application manifest file.
4. Deploy the application with the PLB constraints specified in the application manifest file.
5. Monitor the placement of services and replicas in the cluster to ensure that they are distributed according to the PLB constraints.

## Step by Step Guide

### Step 1: Determine the key-value pairs for node properties and placement constraints

### Step 2: Assign values to node type in the cluster based on the custom properties

### Step 3: Define expression using node properties in the application manifest file

### Step 4: Deploy the application with the PLB constraints specified in the application manifest file or dynamically using PowerShell

### Step 5: Monitor the placement of services and replicas in the cluster

## Example PowerShell Commands

To configure PLB constraints dynamically using PowerShell, you can use the following commands:

### Connect to cluster

From an admin machine with [Service Fabric SDK](https://learn.microsoft.com/azure/service-fabric/service-fabric-get-started) installed, open a [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (pwsh.exe) window and run the following commands to connect to the Service Fabric cluster. These commands do require PowerShell 6+, Azure 'Az.Accounts', and 'Az.Resources' modules to be installed. [Connect-ServiceFabricCluster](https://learn.microsoft.com/powershell/module/servicefabric/connect-servicefabriccluster) cmdlet is used to connect to the cluster and has many options. Refer to online documentation and [Connecting to secure clusters with PowerShell](Connecting%20to%20secure%20clusters%20with%20PowerShell.md):

```powershell
Import-Module ServiceFabric
# Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser
# Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser

# Connect to the cluster has many options, here is an example using X509 certificate
Connect-ServiceFabricCluster -ConnectionEndpoint "mycluster.westus.cloudapp.azure.com:19000" `
    -X509Credential `
    -ServerCertThumbprint "<server thumbprint>" `
    -FindType FindByThumbprint `
    -FindValue "<client thumbprint>"

Connect-AzAccount
```

### Add / Update / Remove key-value pairs for node properties

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

foreach($nodeType in $cluster.resources.properties.nodeTypes) {
    if($nodeType.name -ine $nodeTypeName) { continue }
    if($addOrRemove -ieq "add"){
        if($nodeType.placementProperties -eq $null) {
            Write-Host "Setting placement properties for node type $nodeTypeName"
            $nodeType.placementProperties = @{$key = $value}
        }
        elseif($nodeType.placementProperties.ContainsKey($key)) {
            Write-Host "Updating placement properties for node type $nodeTypeName"
            $nodeType.placementProperties.$key = $value
        }
        else {
            Write-Host "Adding placement properties for node type $nodeTypeName"
            $nodeType.placementProperties.Add($key, $value)
        }
    }
    elseif($addOrRemove -ieq "remove") {
        if($nodeType.placementProperties -ne $null `
            -and $nodeType.placementProperties.ContainsKey($key)) {
            Write-Host "Removing placement properties for node type $nodeTypeName"
            $nodeType.placementProperties.Remove($key)
        }
        else {
            Write-Host "Key not found for $nodeTypeName"
        }
    }
}

$cluster | ConvertTo-Json -Depth 100 | Out-File -Path $jsonFile -Force
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile $jsonFile `
  -Mode Incremental `
  -Verbose
```

### Create a new service with placement constraints

```powershell
New-ServiceFabricService -ApplicationName $applicationName `
  -ServiceName $serviceName `
  -ServiceTypeName $serviceType `
  -Stateful -MinReplicaSetSize 3 `
  -TargetReplicaSetSize 3 `
  -PartitionSchemeSingleton `
  -PlacementConstraint "HasSSD == true && SomeProperty >= 4"
```

### Update an existing service with placement constraints

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

### PowerShell Commands

- `Get-ServiceFabricClusterManifest` - Retrieves the cluster manifest for the Service Fabric cluster.
- `Get-ServiceFabricNode` - Retrieves information about the nodes in the Service Fabric cluster.
- `Get-ServiceFabricDeployedApplication` - Retrieves information about the applications deployed in the Service Fabric cluster on a node.
- `Get-ServiceFabricService -Application <fabric:/Application Name>` - Retrieves information about the services deployed in the Service Fabric cluster.
- `Get-ServiceFabricReplica` - Retrieves information about the replicas deployed in the Service Fabric cluster.

## Reference

- [Node properties and placement constraints](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-cluster-description#node-properties-and-placement-constraints)

- [Describe an application in ApplicationManifest.xml](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-manifests#describe-an-application-in-applicationmanifestxml)

- [Service Fabric Cluster Resource Manager](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-balancing)

- [Introduction to dynamic node tags](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-node-tagging)

- [Advanced Placement Properties](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-advanced-placement-rules-placement-policies)

- [Service Fabric Service Model Schema Elements](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#placementconstraints-element)
