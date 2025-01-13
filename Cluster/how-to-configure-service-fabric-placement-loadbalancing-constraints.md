# How to Configure Service Fabric Placement and Load Balancing Constraints

This article explains how to configure Service Fabric placement and load balancing constraints (PLB). It is based on the official documentation and provides a step-by-step guide with examples.

PLB is a feature of Service Fabric that allows you to control the placement of services and replicas on nodes in the cluster. Typically, this is done with default built-in constraints `NodeType` or `NodeName`, but you can also define custom constraints to optimize the placement of services and replicas based on specific requirements.

PLB constraints are specified in both the application manifest file for your Service Fabric application and as tags on a node. You can use the `PlacementConstraints` and `NodeProperties` elements to define constraints that control where services and replicas are placed in the cluster.

PLB constraints can be configured to constrain the placement of services and replicas based on node properties such as capacity, load, or other custom attributes. You can use PLB constraints to ensure that services and replicas are distributed evenly across the cluster, or to optimize the placement of services and replicas based on specific requirements. PLB contraints are configured by specifying key-value pairs for node properties and placement constraints in the application manifest file.

## Requirements

- Service Fabric Cluster (unmanaged, managed, or standalone)

## Placement Design

Determining the key-value pairs for the node properties and placement constraints is the first step in configuring PLB constraints. You can use `NodeType` or `NodeName` as built-in properties, or define custom properties based on your requirements.

Resource capacity, load, or other custom attributes can be used as node properties to optimize the placement of services and replicas in the cluster. You can define custom properties in the application manifest file and assign values to nodes in the cluster.

## Placement Expression operators

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

## Process

1. Determine the key-value pairs for node properties and placement constraints.
2. If not using default properties, assign values to nodes in the cluster based on the custom properties.
3. Define expression using node properties in the application manifest file.
4. Deploy the application with the PLB constraints specified in the application manifest file.
5. Monitor the placement of services and replicas in the cluster to ensure that they are distributed according to the PLB constraints.

## Step by Step Guide

### Step 1: Determine the key-value pairs for node properties and placement constraints

### Step 2: Assign values to nodes in the cluster based on the custom properties

### Step 3: Define expression using node properties in the application manifest file

### Step 4: Deploy the application with the PLB constraints specified in the application manifest file

### Step 5: Monitor the placement of services and replicas in the cluster

## Troubleshooting

### PowerShell Commands

- `Get-ServiceFabricClusterManifest` - Retrieves the cluster manifest for the Service Fabric cluster.
- `Get-ServiceFabricNode` - Retrieves information about the nodes in the Service Fabric cluster.
- `Get-ServiceFabricDeployedApplication` - Retrieves information about the applications deployed in the Service Fabric cluster on a node.
- `Get-ServiceFabricService` - Retrieves information about the services deployed in the Service Fabric cluster.
- `Get-ServiceFabricReplica` - Retrieves information about the replicas deployed in the Service Fabric cluster.


### Enumerating the node properties

## Reference

- [Node properties and placement constraints](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-resource-manager-cluster-description#node-properties-and-placement-constraints)

- [Describe and application in ApplicationManifest.xml](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-manifests#describe-an-application-in-applicationmanifestxml)
