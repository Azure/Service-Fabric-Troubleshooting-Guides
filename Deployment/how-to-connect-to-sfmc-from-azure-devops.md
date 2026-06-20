# How to Connect to Service Fabric Managed Clusters from Azure DevOps

> **Last validated:** March 2026

This guide covers connecting to a Service Fabric Managed Cluster (SFMC) from Azure DevOps pipelines using `Connect-ServiceFabricCluster` in a `PowerShell@2` task. This is required for SF SDK operations: health checks, application deployment via SDK, service queries, and other operations on port 19000.

For deploying or managing SFMC cluster resources (create cluster, add node types, deploy apps via ARM), see [How to Deploy SFMC from Azure DevOps](how-to-deploy-sfmc-from-azure-devops.md). Those operations use the ARM API and do not require the steps in this guide.

---

## Quick Reference - Already Seeing a Connection Failure?

| Error | Cause | Fix |
|-------|-------|-----|
| `FABRIC_E_SERVER_AUTHENTICATION_FAILED: 0x800b0109` | Server certificate chain validation failed | Use `PowerShell@2` with `-ServerCertThumbprint` ([see below](#why-powershell2)) |
| `FABRIC_E_SERVER_AUTHENTICATION_FAILED: CertificateNotMatched` | Server Common Name set to public FQDN instead of SFMC internal CN | [See anti-patterns](#what-not-to-do) |
| `0x80071C49` - Could not ping gateway endpoints | Agent cannot reach cluster port 19000 | [See NSG configuration](#azure-network-security-group-nsg-configuration) |
| Connection worked before, now fails | Server cert rotated; thumbprint was hardcoded | Use dynamic ARM lookup ([see examples below](#option-1-self-signed-client-certificate)) |

---

## Why PowerShell@2?

The built-in ADO task `ServiceFabricPowerShell@1` validates SFMC server certificates using full X.509 chain validation. SFMC server certificates are signed by a root CA that is not in the Windows Trusted Root store by default, so connections through the built-in task fail.

**The solution:** Use `PowerShell@2` and call `Connect-ServiceFabricCluster` directly with the `-ServerCertThumbprint` parameter. This uses pin-based validation (thumbprint match only) instead of chain validation - no root CA trust required.

The server certificate thumbprint is resolved dynamically from the ARM API at runtime, so it automatically tracks SFMC's server certificate rotations with **zero maintenance**.

---

## Prerequisites (All Options)

- **Self-hosted agent** (or Microsoft-hosted with additional setup)
- **`Az.Resources`** module - for dynamic server cert thumbprint lookup
- **`ServiceFabric`** SDK module - for `Connect-ServiceFabricCluster`
- **NSG rule** allowing the agent to reach port 19000 ([see below](#azure-network-security-group-nsg-configuration))
- Agent service principal has at least **Reader** access to the SFMC resource

---

## Choose Your Authentication Method

| | **Option 1** | **Option 2** | **Option 3** | **Option 4** |
|---|---|---|---|---|
| **Auth type** | Self-signed client cert | CA-signed client cert | Entra + cert credential | Entra + client secret |
| **SFMC registration** | Thumbprint | Common Name + issuer thumbprint | N/A (Entra users) | N/A (Entra users) |
| **Rotation touch points** | 3 (SFMC + ADO + agent) | 2 (ADO + agent) | 1 (Entra app reg) | 1 (secret refresh) |
| **SFMC config change on rotation** | Yes | No | No | No |
| **Works on existing cluster** | Yes | Yes | Only if Entra configured at creation | Only if Entra configured at creation |
| **Requires CA infrastructure** | No | Yes | No | No |
| **Requires non-MFA service account** | No | No | Yes | Yes |
| **Setup complexity** | Low | Medium | High | Medium |

**Recommendation:**
- **Fastest to unblock** → Option 1
- **Lowest ongoing maintenance (cert)** → Option 2
- **Already have Entra on the cluster** → Option 3 or Option 4

> **Best practice:** Option 2 (private CA common name cert) is the recommended long-term approach. When a cert is renewed by the same CA, the common name and issuer thumbprint stay the same -- SFMC client registration does not change on rotation. Combined with a deterministic FQDN ([`domainNameLabel`](#optional-deterministic-fqdn-with-domainnamelabel)) and an Azure DNS CNAME, this gives a fully stable, low-maintenance configuration. See [How to Configure SFMC with Common Name Certificate](../Security/How%20to%20Configure%20a%20Service%20Fabric%20Managed%20Cluster%20with%20Common%20Name%20Certificate.md) for detailed setup.

---

## Option 1: Self-Signed Client Certificate

The simplest setup. 3 rotation touch points when the certificate expires.

### Step 1 - Generate a Self-Signed Client Certificate

```powershell
$certParams = @{
    Subject           = 'CN=ado-sf-client'
    KeyUsage          = 'DigitalSignature'
    KeyAlgorithm      = 'RSA'
    KeyLength         = 2048
    NotAfter          = (Get-Date).AddYears(1)
    CertStoreLocation = 'Cert:\CurrentUser\My'
    TextExtension     = @('2.5.29.37={text}1.3.6.1.5.5.7.3.2')  # Client Authentication EKU
}
$cert = New-SelfSignedCertificate @certParams
Write-Host "Client cert thumbprint: $($cert.Thumbprint)"

# Export PFX for ADO service connection
$pfxPassword = ConvertTo-SecureString -String 'YourPfxPassword' -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath '.\ado-sf-client.pfx' -Password $pfxPassword
```

### Step 2 - Register on SFMC

```powershell
Add-AzServiceFabricManagedClusterClientCertificate `
    -ResourceGroupName $rgName `
    -ClusterName $clusterName `
    -Thumbprint $cert.Thumbprint `
    -Admin
```

Or in an ARM template:

```json
"clients": [
  {
    "isAdmin": true,
    "thumbprint": "<client-cert-thumbprint>"
  }
]
```

### Step 3 - Install Client Certificate on Agent

```powershell
$pfxPassword = ConvertTo-SecureString -String 'YourPfxPassword' -Force -AsPlainText
Import-PfxCertificate -FilePath '.\ado-sf-client.pfx' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -Password $pfxPassword
```

### Step 4 - Pipeline YAML

```yaml
- task: PowerShell@2
  displayName: 'Connect to SFMC and run SF commands'
  inputs:
    targetType: 'inline'
    pwsh: false          # Windows PowerShell 5.1 required for SF SDK
    script: |
      $clusterFqdn     = "$(ClusterFqdn)"
      $clientCertThumb = "$(ClientCertThumbprint)"
      $clusterName     = "$(ClusterName)"
      $resourceGroup   = "$(ClusterResourceGroup)"

      # Resolve current server cert thumbprint from ARM (auto-tracks rotations)
      Import-Module Az.Resources
      $cluster = Get-AzResource -Name $clusterName -ResourceGroupName $resourceGroup `
                   -ResourceType 'Microsoft.ServiceFabric/managedclusters'
      $serverCertThumb = $cluster.Properties.clusterCertificateThumbprints
      Write-Host "Server cert thumbprint: $serverCertThumb"

      # Connect using pin-based validation
      Import-Module ServiceFabric
      Connect-ServiceFabricCluster `
        -ConnectionEndpoint "${clusterFqdn}:19000" `
        -X509Credential `
        -FindType FindByThumbprint `
        -FindValue $clientCertThumb `
        -ServerCertThumbprint $serverCertThumb `
        -StoreLocation CurrentUser `
        -StoreName My

      # Your commands here
      Get-ServiceFabricClusterHealth
```

### Rotation (Option 1)

When the client certificate expires, update **all three**:
1. **SFMC:** Remove old thumbprint, add new thumbprint to `clients[]`
2. **ADO:** Update `ClientCertThumbprint` pipeline variable
3. **Agent:** Import new certificate into `CurrentUser\My`

Server cert rotation: **automatic** - resolved dynamically at runtime.

---

## Option 2: CA-Signed Client Certificate

Uses a certificate signed by a real CA (internal enterprise PKI or external CA). SFMC is registered with the cert's Common Name and issuer thumbprint. When the cert is renewed by the same CA, CN and issuer stay the same - **SFMC configuration does not change on rotation**.

> **Key Vault is not a CA.** It is a certificate store. Use `-IssuerName 'Unknown'` to generate a CSR, get it signed by your CA, then merge the signed cert back into KV. Do **not** use `-IssuerName 'Self'` - self-signed certs change their issuer thumbprint on every renewal, defeating the purpose.

### Step 1 - Generate CSR in Key Vault and Get It Signed

```powershell
$policy = New-AzKeyVaultCertificatePolicy `
    -SubjectName 'CN=ado-sf-client-mycluster' `
    -IssuerName 'Unknown' `
    -ValidityInMonths 12 `
    -KeyType RSA `
    -KeySize 2048 `
    -KeyUsage DigitalSignature `
    -Ekus '1.3.6.1.5.5.7.3.2'   # Client Authentication EKU

# KV creates key pair + pending CSR
$op = Add-AzKeyVaultCertificate -VaultName $kvName -Name 'ado-sf-client' -CertificatePolicy $policy
$csrBase64 = $op.CertificateSigningRequest

# Save CSR for submission to your CA
$csrBytes = [Convert]::FromBase64String($csrBase64)
[System.IO.File]::WriteAllBytes(".\ado-sf-client.csr", $csrBytes)
Write-Host "Submit ado-sf-client.csr to your CA for signing"

# After CA signs the CSR and returns a .cer file:
Import-AzKeyVaultCertificate -VaultName $kvName -Name 'ado-sf-client' `
    -FilePath '.\ado-sf-client-signed.cer'

# Get the issuer's thumbprint for SFMC registration
$cert = Get-AzKeyVaultCertificate -VaultName $kvName -Name 'ado-sf-client'
$chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
$chain.Build($cert.Certificate) | Out-Null
$issuerCert = $chain.ChainElements[1].Certificate
$issuerThumbprint = $issuerCert.Thumbprint
Write-Host "Issuer (CA) thumbprint: $issuerThumbprint"
```

### Step 2 - Register on SFMC by Common Name

```powershell
Add-AzServiceFabricManagedClusterClientCertificate `
    -ResourceGroupName $rgName `
    -ClusterName $clusterName `
    -CommonName 'ado-sf-client-mycluster' `
    -IssuerThumbprint $issuerThumbprint `
    -Admin
```

Or in an ARM template:

```json
"clients": [
  {
    "isAdmin": true,
    "commonName": "ado-sf-client-mycluster",
    "issuerThumbprint": "<issuing-CA-cert-thumbprint>"
  }
]
```

### Step 3 - Install on Agent and Configure Pipeline

Same as Option 1 Steps 3-4. Set `ClientCertThumbprint` to the current leaf cert thumbprint.

### Rotation (Option 2)

When the certificate is renewed (new leaf cert, same CN and issuer), update **two** places:
1. **ADO:** Update `ClientCertThumbprint` pipeline variable
2. **Agent:** Import new certificate into `CurrentUser\My`

**SFMC configuration does not change** - CN and issuer thumbprint remain the same.

---

## Option 3: Entra (AAD) Auth with Certificate Credential

Uses Entra app registration with a certificate credential for unattended auth. Requires Entra to have been configured at cluster creation time.

### Constraints

| Constraint | Detail |
|------------|--------|
| Cluster creation time only | `azureActiveDirectory` must be set when the cluster is created. Cannot be added later. |
| App registrations required | Two Entra app registrations (cluster + client), admin consent, and role assignments. |
| Certificate management | Certificate uploaded to Entra app registration must be rotated when it expires. |

### Prerequisites

- SFMC cluster created with `azureActiveDirectory` property (`tenantId`, `clusterApplication`, `clientApplication`)
- Entra **cluster app registration** (web app) with `user_impersonation` scope and Admin/ReadOnly app roles
- Entra **client app registration** with certificate credential uploaded
- Certificate installed on the agent in `CurrentUser\My`

### Pipeline YAML

```yaml
- task: PowerShell@2
  displayName: 'Connect to SFMC via Entra cert auth'
  inputs:
    targetType: 'inline'
    pwsh: false
    script: |
      $clusterFqdn   = "$(ClusterFqdn)"
      $clusterName   = "$(ClusterName)"
      $resourceGroup = "$(ClusterResourceGroup)"
      $tenantId      = "$(TenantId)"
      $clientAppId   = "$(EntraClientAppId)"
      $certThumb     = "$(EntraCertThumbprint)"

      # Resolve server cert thumbprint
      Import-Module Az.Resources
      $cluster = Get-AzResource -Name $clusterName -ResourceGroupName $resourceGroup `
                   -ResourceType 'Microsoft.ServiceFabric/managedclusters'
      $serverCertThumb = $cluster.Properties.clusterCertificateThumbprints

      # Acquire token via MSAL with certificate credential
      Import-Module MSAL.PS
      $cert = Get-ChildItem "Cert:\CurrentUser\My\$certThumb"
      $token = Get-MsalToken `
        -ClientId $clientAppId `
        -TenantId $tenantId `
        -ClientCertificate $cert `
        -Scopes "$($cluster.Properties.azureActiveDirectory.clusterApplication)/.default"

      # Connect with token + pin-based server cert validation
      Import-Module ServiceFabric
      Connect-ServiceFabricCluster `
        -ConnectionEndpoint "${clusterFqdn}:19000" `
        -AzureActiveDirectory `
        -SecurityToken $token.AccessToken `
        -ServerCertThumbprint $serverCertThumb

      Get-ServiceFabricClusterHealth
```

### Rotation (Option 3)

| What rotates | Action |
|---|---|
| Server cert (~270 days) | **None** - resolved dynamically |
| Entra cert credential | Upload new cert to Entra app registration; update agent cert store (1-2 places) |

---

## Option 4: Entra (AAD) Auth with Client Secret

Simplest Entra option. Uses ROPC (Resource Owner Password Credential) flow with a username and password.

### Constraints

| Constraint | Detail |
|------------|--------|
| Cluster creation time only | `azureActiveDirectory` must be set when the cluster is created. |
| Non-MFA account required | ROPC cannot handle interactive MFA. Requires a dedicated service account. |
| Legacy auth flow | Microsoft [discourages ROPC](https://learn.microsoft.com/azure/active-directory/develop/v2-oauth-ropc). Conditional Access policies may block it. |

### Prerequisites

- Same Entra setup as Option 3 (cluster + client app registrations)
- Non-MFA Entra user account assigned to Admin role on the cluster app

### Pipeline YAML

```yaml
- task: PowerShell@2
  displayName: 'Connect to SFMC via Entra ROPC'
  inputs:
    targetType: 'inline'
    pwsh: false
    script: |
      $clusterFqdn   = "$(ClusterFqdn)"
      $clusterName   = "$(ClusterName)"
      $resourceGroup = "$(ClusterResourceGroup)"

      # Resolve server cert thumbprint
      Import-Module Az.Resources
      $cluster = Get-AzResource -Name $clusterName -ResourceGroupName $resourceGroup `
                   -ResourceType 'Microsoft.ServiceFabric/managedclusters'
      $serverCertThumb = $cluster.Properties.clusterCertificateThumbprints

      # Connect with Entra auth + pin-based server cert validation
      Import-Module ServiceFabric
      Connect-ServiceFabricCluster `
        -ConnectionEndpoint "${clusterFqdn}:19000" `
        -AzureActiveDirectory `
        -ServerCertThumbprint $serverCertThumb `
        -Verbose

      Get-ServiceFabricClusterHealth
```

> **Note:** `-AzureActiveDirectory` without `-SecurityToken` triggers an interactive browser prompt. For fully unattended execution, acquire a token via ROPC and pass it with `-SecurityToken`:
>
> ```powershell
> Import-Module MSAL.PS
> $securePassword = ConvertTo-SecureString "$(EntraPassword)" -AsPlainText -Force
> $token = Get-MsalToken `
>   -ClientId "$(EntraClientAppId)" `
>   -TenantId "$(TenantId)" `
>   -UserCredential (New-Object PSCredential("$(EntraUsername)", $securePassword))
>
> Connect-ServiceFabricCluster `
>   -ConnectionEndpoint "${clusterFqdn}:19000" `
>   -AzureActiveDirectory `
>   -SecurityToken $token.AccessToken `
>   -ServerCertThumbprint $serverCertThumb
> ```

### Rotation (Option 4)

| What rotates | Action |
|---|---|
| Server cert (~270 days) | **None** - resolved dynamically |
| Entra password | Update ADO pipeline secret variable (1 place) |

---

## Azure Network Security Group (NSG) Configuration

The ADO agent must reach the cluster on port 19000. Use the `AzureCloud` service tag for hosted agents or specific IPs for self-hosted agents.

> Use service tag **`AzureCloud`** (not `AzureDevOps`) for the inbound rule.

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

For self-hosted agents, replace the service tag with the agent IP. ADO hosted agent IP ranges: [Microsoft docs](https://docs.microsoft.com/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops#ip-ranges).

---

## What NOT to Do

| Approach | Why it fails |
|----------|-------------|
| Hardcode the server cert thumbprint | SFMC rotates the server cert ~every 270 days; hardcoded thumbprint breaks silently |
| Set Server Common Name to the public FQDN | SFMC server cert CN is `<guid>.sfmc.azclient.ms` - public FQDN does not match |
| Patch ADO task `.ps1` files on the agent | Overwritten on every agent update - fragile and unsupported |
| Use self-signed cert with CN-based SFMC registration | Self-signed certs are their own issuer; issuer thumbprint changes on every renewal |
| Use Key Vault `-IssuerName 'Self'` for CN-based registration | Same problem - KV self-signed certs change issuer thumbprint on renewal |

---

## Troubleshooting

### Test Network Connectivity

```yaml
- task: PowerShell@2
  displayName: 'Test connectivity to cluster'
  inputs:
    targetType: 'inline'
    pwsh: false
    script: |
      $publicIp = (Invoke-RestMethod https://ipinfo.io/json).ip
      Write-Host "Agent public IP: $publicIp"
      $result = Test-NetConnection -ComputerName "$(ClusterFqdn)" -Port 19000
      Write-Host ($result | Format-List * | Out-String)
      if (!$result.TcpTestSucceeded) { throw "Cannot reach cluster on port 19000" }
```

### Verify Client Certificate Is Installed

```powershell
Get-ChildItem 'Cert:\CurrentUser\My' | Where-Object { $_.Thumbprint -eq $clientCertThumbprint }
```

### Test Connection Locally

```powershell
Import-Module ServiceFabric
Import-Module Az.Resources

$cluster = Get-AzResource -Name 'mycluster' -ResourceGroupName 'mycluster-rg' `
             -ResourceType 'Microsoft.ServiceFabric/managedclusters'
$serverCertThumb = $cluster.Properties.clusterCertificateThumbprints

Connect-ServiceFabricCluster `
    -ConnectionEndpoint "$($cluster.Properties.fqdn):19000" `
    -X509Credential `
    -FindType FindByThumbprint `
    -FindValue '<client-cert-thumbprint>' `
    -ServerCertThumbprint $serverCertThumb `
    -StoreLocation CurrentUser `
    -StoreName My `
    -Verbose

Get-ServiceFabricClusterHealth
```

### Enable Debug Logging in ADO

```yaml
variables:
  System.Debug: true
```

---

## Optional: Deterministic FQDN with `domainNameLabel`

SFMC clusters default to a GUID-based FQDN that changes if the cluster is deleted and redeployed. Set `autoGeneratedDomainNameLabelScope: "ResourceGroupReuse"` at cluster creation to get a deterministic FQDN (`<cluster-name>.<hash>.<region>.sfmc.io`) that remains stable across delete/redeploy cycles as long as the cluster name and resource group stay the same.

This is important for:
- **Azure DNS CNAME records** pointing to the cluster
- **APIM backends** or other services configured with the cluster FQDN
- **Firewall rules** or **NSG rules** referencing the FQDN
- **ADO pipeline variables** that would otherwise need updating after a redeploy

Does not affect certificate validation -- the SFMC server cert CN remains `<guid>.sfmc.azclient.ms` regardless of the FQDN label. Combined with a private CA common name client cert (Option 2) and an Azure DNS CNAME, this gives a fully stable endpoint with zero-touch client cert rotation.

See [Service Fabric managed cluster configuration options](https://learn.microsoft.com/azure/service-fabric/how-to-managed-cluster-configuration) for the full ARM property reference including `autoGeneratedDomainNameLabelScope`.

---

## Reference

- [How to Deploy SFMC from Azure DevOps](how-to-deploy-sfmc-from-azure-devops.md) - ARM-based cluster and app deployment
- [Az.ServiceFabric module reference](https://learn.microsoft.com/powershell/module/az.servicefabric/)
- [Service Fabric cluster security scenarios](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-security)
- [Service Fabric Entra configuration](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-azure-ad-via-portal)
- [ADO allowed IP ranges](https://docs.microsoft.com/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops#ip-ranges)
