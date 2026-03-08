# How to Configure Azure DevOps for Service Fabric Managed Clusters

> **Last updated:** March 2026

This guide covers using Azure DevOps (ADO) pipelines with Service Fabric Managed Clusters (SFMC). There are two common scenarios - choose the one that matches what you need to do:

---

## Which Guide Do I Need?

| I want to... | Guide |
|---|---|
| **Deploy or manage SFMC cluster resources** (create/update cluster, add node types, deploy applications via ARM) | [How to Deploy SFMC from Azure DevOps](how-to-deploy-sfmc-from-azure-devops.md) |
| **Run SF SDK commands against a cluster** (health checks, application deployment via SDK, service queries, `Connect-ServiceFabricCluster`) | [How to Connect to SFMC from Azure DevOps](how-to-connect-to-sfmc-from-azure-devops.md) |
| **Both** - deploy resources and then validate the cluster | Start with the [Deploy](how-to-deploy-sfmc-from-azure-devops.md) guide, which includes a [unified pipeline example](how-to-deploy-sfmc-from-azure-devops.md#unified-pipeline-example-deploy--validate) |

---

## Summary of Options

### Deploying SFMC Resources ([details](how-to-deploy-sfmc-from-azure-devops.md))

These operations go through the Azure Resource Manager API (`management.azure.com`). They use a standard Azure service connection (service principal) and do not connect to the cluster directly - no special certificate configuration needed.

| Option | ADO Task | Description |
|---|---|---|
| 1 | `AzurePowerShell@5` | `Az.ServiceFabric` cmdlets - `New-AzServiceFabricManagedCluster`, `New-AzServiceFabricManagedNodeType`, etc. |
| 2 | `AzurePowerShell@5` | `New-AzResourceGroupDeployment` with ARM/Bicep templates |
| 3 | `AzureResourceManagerTemplateDeployment@3` | Built-in OOB ARM task |

### Connecting to SFMC via SF SDK ([details](how-to-connect-to-sfmc-from-azure-devops.md))

These operations connect directly to the cluster on port 19000 using `Connect-ServiceFabricCluster` in a `PowerShell@2` task. The connection uses `-ServerCertThumbprint` for server certificate validation, with the thumbprint resolved dynamically from the ARM API at runtime - no maintenance required for server certificate rotations.

| Option | Client Auth Type | Rotation Touch Points | Setup Complexity |
|---|---|---|---|
| 1 | Self-signed client cert | 3 (SFMC + ADO + agent) | Low |
| 2 | CA-signed client cert | 2 (ADO + agent) | Medium |
| 3 | Entra (AAD) + cert credential | 1 | High |
| 4 | Entra (AAD) + client secret (ROPC) | 1 | Medium |

---

## Background

### Previous Approach

Earlier versions of this guide recommended using the built-in `ServiceFabricPowerShell@1` ADO task with Entra (AAD) authentication and Microsoft-hosted agents. This approach relied on the SFMC server certificate's root CA (`CN=Commercial Cloud Root CA R1`) being pre-installed in the agent's trusted root store.

Microsoft-hosted agent images no longer include this root CA, so connections through the built-in task now fail with `FABRIC_E_SERVER_AUTHENTICATION_FAILED: 0x800b0109` (CERT_E_UNTRUSTEDROOT).

### Current Approach

The updated guides use `PowerShell@2` with `-ServerCertThumbprint` for SF SDK operations. This parameter uses pin-based validation (thumbprint match) rather than full chain validation, so it works regardless of whether the root CA is trusted. The server cert thumbprint is resolved dynamically from the ARM API at runtime, automatically tracking SFMC's server certificate rotations.

For ARM-based deployments, the standard Azure service connection and ARM tasks work without any special configuration - these operations go through `management.azure.com` and do not involve the SFMC server certificate.

---

## Network Configuration

All scenarios require the ADO agent to reach the cluster. For ARM operations, outbound access to `management.azure.com` (443) is sufficient. For SF SDK operations, inbound access to port 19000 is also required.

Use service tag **`AzureCloud`** (not `AzureDevOps`) for NSG inbound rules:

| Setting | Value |
|---------|-------|
| Source | Service Tag |
| Source service tag | `AzureCloud` |
| Source port ranges | `*` |
| Destination | Any |
| Destination port ranges | `19000` |
| Protocol | TCP |
| Action | Allow |
| Priority | 110 |
| Name | `AzureDevOpsDeployment` |

For self-hosted agents, use the agent IP instead of the service tag. ADO hosted agent IP ranges: [Microsoft docs](https://docs.microsoft.com/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops#ip-ranges).

---

## Reference

- [How to Deploy SFMC from Azure DevOps](how-to-deploy-sfmc-from-azure-devops.md)
- [How to Connect to SFMC from Azure DevOps](how-to-connect-to-sfmc-from-azure-devops.md)
- [Az.ServiceFabric module reference](https://learn.microsoft.com/powershell/module/az.servicefabric/)
- [SFMC ARM template reference](https://learn.microsoft.com/azure/templates/microsoft.servicefabric/managedclusters)
- [Service Fabric cluster security scenarios](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-security)
- [Service Fabric Entra configuration](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-azure-ad-via-portal)
- [ADO allowed IP ranges](https://docs.microsoft.com/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops#ip-ranges)
