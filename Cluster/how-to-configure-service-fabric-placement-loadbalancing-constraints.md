# How to Configure Service Fabric Placement Properties and Load Balancing Constraints

This guide explains how to control where services and replicas run in a Service Fabric cluster using node properties and Placement and Load Balancing (PLB) constraints. PLB is a core feature of Service Fabric's Cluster Resource Manager (CRM) that lets you influence service placement.

You can apply constraints:

- Statically in the ApplicationManifest.xml
- Dynamically via PowerShell

While built-in properties (`NodeType`, `NodeName`) work for many scenarios, custom properties (e.g., `HasSSD`, `IsHighMemory`) can address specific requirements.

## Alternatives to PLB Constraints

- **Dynamic Node Tags**: Runtime-configurable tags via PowerShell without expression syntax. See [Dynamic node tags](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-node-tagging).
- **Cluster Resource Manager (CRM)**: Balances placement using metrics (PrimaryCount, ReplicaCount, CPU, memory, custom metrics). See [CRM balancing](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-balancing).
- **Resource Governance**: Controls CPU/memory per service; complements PLB constraints for resource-aware placement. See [Resource Governance](https://learn.microsoft.com/azure/service-fabric/service-fabric-resource-governance).

## Best Practices

- Use `NodeType` (built-in) rather than `NodeName` (single point of failure)
- Define constraints in **ApplicationManifest.xml** to persist across upgrades
- Create custom properties only when built-in ones are insufficient
- Plan for maintenance using upgrade domains

## Implementation Process

1. Choose the appropriate placement solution (PLB, dynamic tags, or resource governance)
2. Define node property key/value pairs and constraint expressions
3. Assign properties to node types via ARM template or PowerShell
4. Configure `PlacementConstraints` in ApplicationManifest.xml or update via PowerShell
5. Deploy or update your application
6. Verify placement in Service Fabric Explorer or via PowerShell

## PowerShell Commands

### Connect to a cluster

From an admin machine with [Service Fabric SDK](https://learn.microsoft.com/azure/service-fabric/service-fabric-get-started) installed:

```powershell
Import-Module ServiceFabric
# Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser
# Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser
Import-Module Az.Accounts
Import-Module Az.Resources

# Connect to the cluster has many options, here is an example using X509 certificate
Connect-ServiceFabricCluster -ConnectionEndpoint "<cluster name>.<region>.cloudapp.azure.com:19000" `
    -X509Credential `
    -ServerCertThumbprint "<server thumbprint>" `
    -FindType FindByThumbprint `
    -FindValue "<client thumbprint>"

Connect-AzAccount
```

### Add/Update/Remove node properties

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

### Configure services with placement constraints

#### Create a new service

```powershell
New-ServiceFabricService -ApplicationName $applicationName `
  -ServiceName $serviceName `
  -ServiceTypeName $serviceType `
  -Stateful -MinReplicaSetSize 3 `
  -TargetReplicaSetSize 3 `
  -PartitionSchemeSingleton `
  -PlacementConstraint "HasSSD == true && SomeProperty >= 4"
```

#### Update an existing service

```powershell
Update-ServiceFabricService -ServiceName $serviceName `
  -Stateful `
  -PlacementConstraint "HasSSD == true && SomeProperty >= 4"
```

## Configuration Examples

### Application Manifest with Placement Constraints

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

### ARM Template: Node Properties

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

### ARM Template: Service with Placement Constraints

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
        "placementConstraints": "(HasSSD == true && NodeType==NodeType0)",
        "serviceLoadMetrics": [],
        "servicePlacementPolicies": [],
        "defaultMoveCost": ""
    }
}
```

## Placement Expression Syntax

Available operators:

- Comparison: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Logical: `&&`, `||`, `!`
- Grouping: `(`, `)`

**Examples:**

- `NodeType == "FrontEnd"`
- `NodeType != "BackEnd"`
- `NodeType == "FrontEnd" && NodeName == "Node1"`
- `NodeType == "FrontEnd" || NodeName == "Node1"`
- `Value > 10`
- `Value <= 10`

## Troubleshooting

### Service Fabric Explorer (SFX)

Verify constraints are correctly applied:

1. Open SFX at `https://<cluster-name>:19080/Explorer`
2. Navigate to Applications → [Your Application] → Manifest
3. Check that placement constraints are defined correctly
4. Verify services and replicas are distributed according to constraints

### Useful PowerShell Commands

- [`Get-ServiceFabricClusterManifest`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricclustermanifest): Retrieves cluster manifest
- [`Get-ServiceFabricApplicationManifest`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricapplicationmanifest): Retrieves application manifest
- [`Get-ServiceFabricNode`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricnode): Shows node information and properties
- [`Get-ServiceFabricService -Application fabric:/<Application Name>`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricservice): Lists services and their constraints
- [`Get-ServiceFabricReplica`](https://learn.microsoft.com/powershell/module/servicefabric/get-servicefabricreplica): Shows replica placement information

## References

- [Node properties and placement constraints](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-cluster-description#node-properties-and-placement-constraints)
- [ApplicationManifest.xml schema](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-manifests#describe-an-application-in-applicationmanifestxml)
- [Service Fabric Cluster Resource Manager](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-balancing)
- [Advanced Placement Properties](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-advanced-placement-rules-placement-policies)
- [Service Fabric Service Model Schema Elements](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#placementconstraints-element)
