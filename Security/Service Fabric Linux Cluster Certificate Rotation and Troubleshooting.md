# Service Fabric Linux Cluster Certificate Rotation and Troubleshooting

This article provides Linux-specific steps for certificate rotation and troubleshooting on Azure Service Fabric Linux clusters. For Windows clusters, see [Fix Expired Cluster Certificate Manual Steps](./Fix%20Expired%20Cluster%20Certificate%20Manual%20Steps.md) or [How to add and swap the Secondary Certificate](./Use%20Azure%20Resource%20Explorer%20to%20add%20the%20Secondary%20Certificate.md).

> [!NOTE]
> The ARM/SFRP-level operations (adding secondary cert, swapping primary/secondary, updating VMSS secrets) are the same for Linux and Windows. The differences are in **on-node certificate format, location, delivery mechanism,** and **troubleshooting**.

## [Applies To]

Azure Service Fabric **Linux** clusters (Ubuntu, Red Hat) secured with X.509 certificates declared by thumbprint.

## [Key Differences: Linux vs Windows]

| Aspect | Windows | Linux |
|--------|---------|-------|
| **Cert format** | PFX (PKCS#12) in Windows cert store | `.crt` + `.prv` (PEM) files or `.pem` files |
| **Cert location** | `LocalMachine\My` cert store | `/var/lib/waagent/` (waagent-delivered) and `/var/lib/sfcerts/` (SF runtime) |
| **Cert delivery** | CRP/VM Agent writes PFX to cert store | waagent downloads `.crt`/`.prv` files to `/var/lib/waagent/` |
| **Old cert removal** | Old certs remain in store | waagent **removes** old certs on goal state change (incarnation update) |
| **ACL/permissions** | `NETWORK SERVICE` ACL on private key | POSIX ACLs granting `sfuser` and `ServiceFabricAdministrators` read/write access (files are owned by `root:root`) |
| **Verification tool** | RDP + `certlm.msc` | SSH + `ls` / `openssl` |
| **Event logs** | `Microsoft-ServiceFabric%4Admin.evtx` | `/var/log/syslog` |
| **Agent logs** | Windows Event Log + bootstrap agent | `/var/log/waagent.log` + bootstrap agent logs in extension directory |
| **Extension type** | `ServiceFabricNode` | `ServiceFabricLinuxNode` |
| **Extension location** | `C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode` | `/var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-{version}` |

## [Certificate File Locations on Linux]

### Waagent-Delivered Certificates (VMSS Secrets)

When certs are deployed via VMSS `osProfile/secrets` (Key Vault), the Azure Linux Agent (waagent) downloads them to:

```text
/var/lib/waagent/{THUMBPRINT_UPPERCASE}.crt    # Public certificate (PEM format)
/var/lib/waagent/{THUMBPRINT_UPPERCASE}.prv    # Private key (PEM format)
```

Example:

```text
/var/lib/waagent/ED815E6241146A1730D6C81F06BD1B5692CC0942.crt
/var/lib/waagent/ED815E6241146A1730D6C81F06BD1B5692CC0942.prv
```

> [!NOTE]
> Waagent also creates `.pem` files alongside the `.crt`/`.prv` files in `/var/lib/waagent/`. You may see files like `{THUMBPRINT}.pem` in addition to the `.crt` and `.prv` files.

> [!IMPORTANT]
> When delivered via VMSS `osProfile/secrets`, waagent uses `.prv` extension for private keys (not `.key`). When using the Key Vault VM extension or manual placement, certificates follow the standard `.crt`/`.key` or single `.pem` format as described in [MS Learn](https://learn.microsoft.com/azure/service-fabric/service-fabric-configure-certificates-linux). The SF bootstrap agent copies/links certs from `/var/lib/waagent/` into `/var/lib/sfcerts/` for the SF runtime.

### Service Fabric Runtime Certificates

The SF runtime expects certificates in:

```text
/var/lib/sfcerts/    # Maps to LocalMachine\My on Windows
```

The SF runtime certificate directory contains more files than the waagent source. Typical contents include:

```text
/var/lib/sfcerts/
  {THUMBPRINT}.crt           # Certificate (PEM)
  {THUMBPRINT}.prv           # Private key (PEM)
  {THUMBPRINT}.pem           # Combined cert+key (PEM)
  {THUMBPRINT}.pfx           # PKCS#12 format
  Certificates.pem           # Aggregated certificate bundle
  TransportCert.pem          # Transport certificate
  TransportPrivate.pem       # Transport private key
  microsoft_root_certificate.pem  # Microsoft root CA
```

Service Fabric expects either a `.pem` file containing both certificate and private key, or a `.crt` file with the certificate and a `.key` file with the private key (per [MS Learn](https://learn.microsoft.com/azure/service-fabric/service-fabric-configure-certificates-linux#location-and-format-of-x509-certificates-on-linux-nodes)).

### Key Vault VM Extension Certificates

If the Key Vault VM extension is installed (recommended for common-name cert declarations with auto-rollover), certs go to:

```text
/var/lib/waagent/Microsoft.Azure.KeyVault.Store/    # KV extension managed certs
```

The Key Vault VM extension delivers certs in `.pem` + `.key` format and supports version-less URIs for automatic certificate renewal. See [Manage certificates in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificate-management) for the recommended auto-rollover pattern.

### Extension Configuration and Logs

```text
/var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-{version}/
├── config/
│   ├── {N}.settings          # Extension settings (contains cert thumbprints)
│   └── {N}.status            # Extension status
├── heartbeat.log             # Node health heartbeat
├── status/                   # Status files
└── ServiceFabricLinuxExtension_install.log
```

### Cluster Manifest

There are two locations with manifest files:

```text
# Extension-staged manifest (temporary, used during bootstrap)
/var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml

# Runtime manifest (authoritative, used by running SF node)
{DataRoot}/{NodeName}/Fabric/ClusterManifest.current.xml
# Example: /mnt/sfroot/_sys_0/Fabric/ClusterManifest.current.xml
```

> [!NOTE]
> `TempClusterManifest.xml` is a staging file used by the extension during node bootstrap. It is **not** updated by cluster configuration upgrades - only `ClusterManifest.current.xml` is updated. The authoritative runtime manifest is `ClusterManifest.current.xml` under the data root. When troubleshooting certificate issues on a running cluster, always check `ClusterManifest.current.xml` first.

> [!TIP]
> `TempClusterManifest.xml` is typically stored as **single-line XML**, so `grep -A2` will not show surrounding context. Use `python3 -m xml.dom.minidom` or `xmllint --format` to pretty-print it before grepping, or use `grep -oP` with regex to extract values.

### Bootstrap Agent Logs

```text
/var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/sfbootstrapagent_{PID}.log
```

## [Certificate Rotation Steps for Linux Clusters]

The ARM/SFRP-level operations are the same for Linux and Windows. See [How to add and swap the Secondary Certificate using Azure Portal](./Use%20Azure%20Resource%20Explorer%20to%20add%20the%20Secondary%20Certificate.md) for the full Windows walkthrough. The steps below include the complete ARM JSON and PowerShell commands with Linux-specific notes.

### Step 1 - Create a New Certificate

Create or obtain a new certificate and upload it to Key Vault. Options:

- Create with any reputable CA
- Generate self-signed certs using Azure Portal -> Key Vault
- Create and upload using PowerShell - [CreateKeyVaultAndCertificateForServiceFabric.ps1](../Scripts/CreateKeyVaultAndCertificateForServiceFabric.ps1)

### Step 2 - Deploy New Cert to VMSS (osProfile/secrets)

Add the new Key Vault secret URL to the VMSS `osProfile/secrets/vaultCertificates` array. Use [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer) to navigate to the VMSS resource, then use [API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground) to PUT the updated configuration. For detailed instructions, see [Managing Azure Resources](../Deployment/managing-azure-resources.md).

If the new certificate is in the **same Key Vault**, add a new entry to the existing `vaultCertificates` array:

```json
"virtualMachineProfile": {
  "osProfile": {
    "secrets": [
      {
        "sourceVault": {
          "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault-name}"
        },
        "vaultCertificates": [
          {
            "certificateUrl": "https://{vault-name}.vault.azure.net/secrets/{old-cert-name}/{version}",
            "certificateStore": null
          },
          {
            "certificateUrl": "https://{vault-name}.vault.azure.net/secrets/{new-cert-name}/{version}",
            "certificateStore": null
          }
        ]
      }
    ]
  }
}
```

If the certificate is in a **different Key Vault**, add a separate entry to the `secrets` array:

```json
"secrets": [
  {
    "sourceVault": {
      "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault-name-1}"
    },
    "vaultCertificates": [
      {
        "certificateUrl": "https://{vault-name-1}.vault.azure.net/secrets/{old-cert-name}/{version}",
        "certificateStore": null
      }
    ]
  },
  {
    "sourceVault": {
      "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault-name-2}"
    },
    "vaultCertificates": [
      {
        "certificateUrl": "https://{vault-name-2}.vault.azure.net/secrets/{new-cert-name}/{version}",
        "certificateStore": null
      }
    ]
  }
]
```

**Alternatively, use PowerShell:**

> [!WARNING]
> `Add-AzServiceFabricClusterCertificate` was deprecated in Az PowerShell module 6.0+ and is no longer available. Use ARM templates, Resource Explorer, or API Playground instead.

```powershell
# DEPRECATED - only works with Az module < 6.0
# Add secondary certificate to the cluster (works for both Linux and Windows clusters)
Add-AzServiceFabricClusterCertificate `
    -ResourceGroupName "{resource-group}" `
    -Name "{cluster-name}" `
    -SecretIdentifier "https://{vault-name}.vault.azure.net/secrets/{cert-name}/{version}"
```

**Or deploy via ARM template** (see [MS Learn - Add a secondary certificate using Azure Resource Manager](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-security-update-certs-azure#add-a-secondary-certificate-using-azure-resource-manager)):

```powershell
# Deploy ARM template with new certificate parameters
New-AzResourceGroupDeployment `
    -ResourceGroupName "{resource-group}" `
    -TemplateFile "{path-to-template.json}" `
    -TemplateParameterFile "{path-to-parameters.json}"
```

Wait for the VMSS `provisioningState` to show `Succeeded` before proceeding.

> [!NOTE]
> On Linux, `certificateStore` is `null` in the VMSS `osProfile/secrets` JSON (not `"My"` as on Windows). Waagent delivers the cert files as `.crt`/`.prv` to `/var/lib/waagent/` regardless of this setting. The SF bootstrap agent searches `/var/lib/waagent/` for cert files.

### Step 3 - Verify Certificate Delivery on Nodes

**This is where Linux differs from Windows.** Instead of RDP + certlm.msc:

1. **SSH** into a node (or use Serial Console / Run Command in Azure Portal)

2. **Check waagent.log for cert download confirmation:**

   ```bash
   grep -i "download" /var/log/waagent.log | grep -i "cert"
   ```

   Successful download entries look like:

   ```text
   INFO ExtHandler Downloaded uris: [ExtHandlerSecretUri(URL=https://myvault.vault.azure.net/secrets/mycert/abc123, StoreLocation=MY, StoreName=MY)]
   ```

3. **List cert files in waagent directory:**

   ```bash
   ls -la /var/lib/waagent/*.crt /var/lib/waagent/*.prv 2>/dev/null
   ```

   You should see `.crt` and `.prv` files for each expected thumbprint.

4. **Verify cert content matches expected thumbprint:**

   ```bash
   openssl x509 -in /var/lib/waagent/{THUMBPRINT}.crt -noout -fingerprint -sha1
   ```

5. **Check /var/lib/sfcerts/ directory:**

   ```bash
   ls -la /var/lib/sfcerts/
   ```

6. **Verify file permissions (sfuser must have read access):**

   ```bash
   # Check basic permissions and ownership
   ls -la /var/lib/waagent/*.crt /var/lib/waagent/*.prv

   # Check POSIX ACLs (files are root:root owned but grant access via ACLs)
   getfacl /var/lib/waagent/{THUMBPRINT}.crt
   getfacl /var/lib/waagent/{THUMBPRINT}.prv
   ```

   > [!NOTE]
   > On SF Linux clusters, cert files are owned by `root:root`. Access for `sfuser` and the `ServiceFabricAdministrators` group is granted via POSIX ACLs, not file ownership. Use `getfacl` to verify the ACL entries.

### Step 4 - Add Secondary Cert to VMSS Extension Settings

Add `certificateSecondary` with the new thumbprint to the VMSS extension settings. Navigate to the VMSS resource in [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer), copy the resource URI, and use [API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground) to PUT the updated configuration.

> [!IMPORTANT]
> On Linux the extension publisher is `Microsoft.Azure.ServiceFabric` and type is **`ServiceFabricLinuxNode`** (not `ServiceFabricNode` as on Windows).

Modify `virtualMachineProfile / extensionProfile / extensions / settings` to add `certificateSecondary`:

```json
"virtualMachineProfile": {
  "extensionProfile": {
    "extensions": [
      {
        "properties": {
          "autoUpgradeMinorVersion": true,
          "settings": {
            "clusterEndpoint": "https://{region}.servicefabric.azure.com/runtime/clusters/{clusterid}",
            "nodeTypeRef": "NodeType0",
            "certificate": {
              "thumbprint": "OLD_THUMBPRINT",
              "x509StoreName": "My"
            },
            "certificateSecondary": {
              "thumbprint": "NEW_THUMBPRINT",
              "x509StoreName": "My"
            }
          },
          "publisher": "Microsoft.Azure.ServiceFabric",
          "type": "ServiceFabricLinuxNode",
          "typeHandlerVersion": "2.0"
        },
        "name": "{nodetype}_ServiceFabricLinuxNode"
      }
    ]
  }
}
```

**Repeat for each node type** (each VMSS). Execute PUT in API Playground and wait for `provisioningState` to show `Succeeded`.

### Step 5 - Update SF Cluster Resource

Add `thumbprintSecondary` to the `Microsoft.ServiceFabric/clusters` resource. Navigate to the SF cluster resource in [Resource Explorer](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer), copy the resource URI, and use [API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground) to PUT the updated configuration:

```json
{
  "type": "Microsoft.ServiceFabric/clusters",
  "properties": {
    "certificate": {
      "thumbprint": "OLD_THUMBPRINT",
      "thumbprintSecondary": "NEW_THUMBPRINT",
      "x509StoreName": "My"
    }
  }
}
```

This triggers SFRP to generate an updated ClusterManifest and initiate a cluster upgrade. Wait for `provisioningState` to reach `Succeeded`. This step can take up to an hour.

> [!IMPORTANT]
> SFRP does **not** automatically update the VMSS extension settings when you update the SF cluster ARM resource. Steps 4 and 5 are independent operations. SFRP only updates the ClusterManifest (which is rolled out via cluster upgrade). You must still manually update the VMSS extension settings (Step 4) to keep them in sync. The on-node extension `.settings` file is only updated when the VMSS instance is reimaged or when a new incarnation triggers the extension.

### Step 6 - Swap and Remove Old Certificate

Once Step 5 completes, swap the primary and secondary thumbprints so the new cert becomes primary:

1. **Swap in each VMSS** (extension settings):

   ```json
   "certificate": {
     "thumbprint": "NEW_THUMBPRINT",
     "x509StoreName": "My"
   },
   "certificateSecondary": {
     "thumbprint": "OLD_THUMBPRINT",
     "x509StoreName": "My"
   }
   ```

   Execute PUT in API Playground for each VMSS. Wait for `provisioningState` `Succeeded`.

2. **Swap in the SF cluster resource**:

   ```json
   "certificate": {
     "thumbprint": "NEW_THUMBPRINT",
     "thumbprintSecondary": "OLD_THUMBPRINT",
     "x509StoreName": "My"
   }
   ```

   Execute PUT in API Playground. Wait for `provisioningState` `Succeeded`.

3. **Remove old certificate** (after swap is complete and cluster is healthy):

   Remove the old cert from `vaultCertificates` in the VMSS `osProfile/secrets`, remove `certificateSecondary` from extension settings, and remove `thumbprintSecondary` from the SF cluster resource.

   Or use PowerShell:

   ```powershell
   Remove-AzServiceFabricClusterCertificate `
       -ResourceGroupName "{resource-group}" `
       -Name "{cluster-name}" `
       -Thumbprint "OLD_THUMBPRINT"
   ```

## [Verify Cluster Manifest Alignment]

This is a critical diagnostic step for both Linux and Windows but is especially important on Linux because waagent removes old certs from disk.

The correct certificate rotation flow is:

1. **Customer** updates the `Microsoft.ServiceFabric/clusters` ARM resource with the new certificate thumbprint(s)
2. **SFRP** processes the ARM update and generates an updated ClusterManifest with the new thumbprints
3. **SFRP** triggers a cluster upgrade to roll out the new manifest to all nodes
4. **VMSS extension settings** are updated with the new thumbprints

> [!IMPORTANT]
> SFRP does **not** independently update the ClusterManifest. The customer must update the SF cluster ARM resource first (via Resource Explorer, API Playground, ARM template, or PowerShell). SFRP generates the ClusterManifest based on the ARM resource definition. If only the VMSS extension settings are updated (e.g., by directly modifying the VMSS resource) without updating the SF cluster resource, the ClusterManifest will be out of sync.

After a certificate update, verify that the **ClusterManifest Security section matches the extension settings**:

1. **Check the ClusterManifest for cert thumbprints:**

   Check the **runtime** manifest (authoritative) first, then the extension staging manifest:

   ```bash
   # Runtime manifest (authoritative - updated by config upgrades)
   DATAROOT="/mnt/sfroot"
   [ ! -d "$DATAROOT" ] && DATAROOT="/mnt/resource/sfroot"
   MANIFEST=$(find "$DATAROOT" -name "ClusterManifest.current.xml" -print -quit 2>/dev/null)
   python3 -c "import xml.dom.minidom,sys; print(xml.dom.minidom.parse('$MANIFEST').toprettyxml())" | grep -i "thumbprint"

   # Extension staging manifest (NOT updated by config upgrades - only reflects bootstrap state)
   # Note: TempClusterManifest.xml is single-line XML, so grep -A2 won't show context
   python3 -c "import xml.dom.minidom; print(xml.dom.minidom.parse('/var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml').toprettyxml())" | grep -i "thumbprint"
   ```

2. **Check the extension settings for cert thumbprints:**

   ```bash
   # Find the latest settings file
   LATEST_SETTINGS=$(ls -t /var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-*/config/*.settings 2>/dev/null | head -1)
   cat "$LATEST_SETTINGS" | python3 -m json.tool | grep -i "thumbprint"
   ```

3. **Compare:** The thumbprints in the ClusterManifest Security section **must match** the thumbprints in the extension settings file. If they don't, the bootstrap agent will fail to start the node.

## [Troubleshooting Certificate Issues on Linux]

### Symptom: Nodes Unreachable / Bootstrap Agent Looping

The SF bootstrap agent (`sfbootstrapagent`) runs in a loop attempting to configure the node. If it cannot find the certificates referenced in the ClusterManifest, it retries indefinitely.

**Diagnosis steps:**

1. **Check bootstrap agent logs:**

   ```bash
   # Find the latest bootstrap agent log
   ls -lt /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/sfbootstrapagent_*.log | head -5

   # Check for cert search errors
   grep -i "FindKVVMExtCerts\|certificate\|error\|failed" \
       /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/sfbootstrapagent_*.log | tail -20
   ```

   Common error pattern:

   ```text
   FindKVVMExtCerts: Looking for Thumbprint {OLD_THUMBPRINT} in /var/lib/waagent
   FindKVVMExtCerts: ERR: certificate not found
   ```

2. **Check waagent.log for cert download history:**

   ```bash
   grep -E "Download|cert|incarnation|GoalState" /var/log/waagent.log | tail -30
   ```

   Key things to look for:
   - **Incarnation changes**: Each VMSS settings update triggers a new incarnation
   - **Certificate downloads**: Confirm new certs were downloaded after the latest incarnation
   - **Certificate removals**: Old certs are removed when they leave the goal state

3. **Check syslog for SF events:**

   ```bash
   grep -i "ServiceFabric\|fabric\|certificate" /var/log/syslog | tail -20
   ```

4. **Check heartbeat.log:**

   ```bash
   EXTENSION_DIR=$(ls -d /var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-* 2>/dev/null | head -1)
   cat "$EXTENSION_DIR/heartbeat.log"
   ```

   A heartbeat file filled with null bytes indicates the extension has not successfully started.

### Symptom: VMSS Extension Settings Updated but ClusterManifest Out of Sync

This is a known failure pattern where the VMSS extension settings have been updated with new certificate thumbprints, but the ClusterManifest still references the old thumbprints. This typically happens when:

- The VMSS resource was updated directly (e.g., via SFRP backend fix or manual VMSS update) without the SF cluster ARM resource being updated first
- The customer updated only the VMSS but forgot to update the `Microsoft.ServiceFabric/clusters` resource
- The SF cluster ARM update failed or partially completed

The result:

- **New certs are on disk** (waagent downloaded them)
- **Old certs are gone** (waagent removed them on incarnation change)
- **Manifest still expects old certs** (ClusterManifest was not regenerated because the SF cluster ARM resource was not updated)
- **Bootstrap agent loops** (looking for old thumbprints that no longer exist as files)

> [!NOTE]
> The correct flow is: **Customer updates SF cluster ARM resource** → **SFRP generates new ClusterManifest** → **Cluster upgrade rolls out new manifest**. SFRP never independently updates the ClusterManifest. If the VMSS settings and manifest are out of sync, it means the SF cluster ARM resource update was missed or failed.

**Diagnosis:**

```bash
# Check which certs are actually on disk
ls /var/lib/waagent/*.crt 2>/dev/null

# Check which certs the manifest expects
grep "Thumbprint" /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml

# Check which certs the settings specify
LATEST_SETTINGS=$(ls -t /var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-*/config/*.settings 2>/dev/null | head -1)
cat "$LATEST_SETTINGS" | python3 -m json.tool | grep -i "thumbprint"
```

**Expected alignment:**

```text
                       Manifest    Settings    On Disk (.crt/.prv)
Old Thumbprint         ✓           ✗           ✗ (removed by waagent)    ← BROKEN
New Thumbprint         ✗           ✓           ✓ (downloaded by waagent) ← BROKEN
```

**Resolution:**

1. **Customer action**: Update the `Microsoft.ServiceFabric/clusters` ARM resource with the correct certificate thumbprint(s) using Resource Explorer / API Playground / ARM template. This will trigger SFRP to generate a new ClusterManifest and roll it out.
2. **If the SF cluster ARM update fails or the cluster is unreachable**: Contact Azure Support. Support can update the SFRP backend record to match the current certificate state, which will allow SFRP to generate the correct ClusterManifest.

### Symptom: Certificate Present but Bootstrap Agent Can't Find It

The SF bootstrap agent searches for certificate files in a specific order:

1. First looks for `/var/lib/waagent/{THUMBPRINT}.crt` + `.prv` files
2. If not found, falls back to scanning all `.pem` files in `/var/lib/waagent/`
3. The `.pem` fallback typically only finds `microsoft_root_certificate.pem` (root CA with no private key)

**Common causes:**
- Thumbprint case mismatch (manifest has lowercase, files are uppercase)
- File permissions prevent sfuser from reading the cert files
- Certs were delivered to a different directory (KV extension vs waagent)

**Verify:**

```bash
# Check exact filenames (thumbprints are uppercase in filenames)
ls -la /var/lib/waagent/*.crt /var/lib/waagent/*.prv 2>/dev/null

# Check if PEM files exist
ls -la /var/lib/waagent/*.pem 2>/dev/null

# Check permissions
stat /var/lib/waagent/{THUMBPRINT}.crt
stat /var/lib/waagent/{THUMBPRINT}.prv
```

### Symptom: Old Certificate Missing After VMSS Update

On Linux, when the VMSS goal state changes (new incarnation), waagent **removes** certificate files that are no longer in the current goal state. This is different from Windows, where old certs remain in the cert store.

**Impact:** If the ClusterManifest still references the old certificate (because the SF cluster ARM resource was not updated), and the old certificate has been removed from disk, the cluster node cannot start.

**Verify by checking waagent.log timeline:**

```bash
# See cert download/remove events with timestamps
grep -E "Download.*cert|Remove.*cert|incarnation" /var/log/waagent.log
```

## [Linux-Specific Recovery Steps for Expired/Missing Certificates]

If the cluster is down because of cert issues and cannot be recovered through normal ARM operations:

> [!IMPORTANT]
> The preferred resolution is always to update the `Microsoft.ServiceFabric/clusters` ARM resource with the correct thumbprint(s), which triggers SFRP to generate the correct ClusterManifest. If the ARM update cannot be applied (e.g., cluster is unreachable, SFRP rejects the update), contact Azure Support to have the SFRP backend record corrected. The options below are emergency workarounds only.

### Option 1: Manual Certificate Placement (Emergency)

> [!WARNING]
> This is an emergency workaround. Proper resolution is to update the SF cluster ARM resource or have Azure Support correct the SFRP backend.

**Prerequisites:**
- SSH access to each node (via Serial Console or Run Command in Azure Portal if SSH endpoint is cert-protected)
- Azure CLI (`az`) may not be installed on SF Linux nodes. If it is not, use an external machine to download the cert and SCP it to the node, or use `curl` with the node's managed identity token to access Key Vault

1. **SSH** to each node

2. **Identify which thumbprint the manifest expects:**

   ```bash
   grep "Thumbprint" /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml
   ```

3. **If the cert exists in Key Vault, download it and place as .crt/.prv:**

   ```bash
   # Option A: Using az CLI (if installed and authenticated)
   az keyvault secret download --vault-name {vault-name} --name {cert-name} --file /tmp/cert.pem

   # Option B: Using curl with managed identity (if VMSS has KV access)
   # Get access token
   TOKEN=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H 'Metadata: true' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
   # Download secret
   curl -s "https://{vault-name}.vault.azure.net/secrets/{cert-name}?api-version=7.4" -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])" > /tmp/cert.pem

   # Extract certificate and private key
   openssl x509 -in /tmp/cert.pem -out /var/lib/waagent/{THUMBPRINT}.crt
   openssl pkey -in /tmp/cert.pem -out /var/lib/waagent/{THUMBPRINT}.prv

   # Set permissions
   chmod 644 /var/lib/waagent/{THUMBPRINT}.crt
   chmod 600 /var/lib/waagent/{THUMBPRINT}.prv

   # Clean up
   rm -f /tmp/cert.pem
   ```

4. **Restart the Azure Linux Agent to trigger the bootstrap agent:**

   ```bash
   sudo systemctl restart walinuxagent
   ```

### Option 2: Update ClusterManifest Manually (Emergency)

> [!WARNING]
> This is an advanced emergency procedure. The ClusterManifest is normally generated by SFRP based on the SF cluster ARM resource. Manually editing it is a temporary fix that will be overwritten on the next cluster upgrade. Contact Azure Support before attempting. After the cluster is recovered, the SF cluster ARM resource must be updated with the correct thumbprints to make the fix permanent.

1. **SSH** to each node

2. **Stop SF processes and the bootstrap agent:**

   > [!NOTE]
   > On modern SF Linux clusters, there are two systemd services: `servicefabric.service` (starts FabricHost via `/opt/microsoft/servicefabric/bin/starthost.sh`) and `servicefabricnodebootstrapagent.service` (the bootstrap agent). Use `systemctl` to stop/start them. On older clusters where these systemd services do not exist, fall back to killing processes directly.

   ```bash
   # Preferred: use systemctl (modern SF Linux clusters)
   sudo systemctl stop servicefabric
   sudo systemctl stop servicefabricnodebootstrapagent

   # Fallback: kill processes directly (older clusters without systemd units)
   # sudo pkill -f sfbootstrapagent || true
   # sudo pkill -f FabricHost || true

   # Wait for processes to exit
   sleep 5
   # Verify they are stopped
   ps aux | grep -E "sfbootstrapagent|FabricHost|Fabric.exe" | grep -v grep
   ```

3. **Edit ClusterManifest to replace old thumbprints with new:**

   ```bash
   sudo cp /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml \
           /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml.bak

   sudo sed -i 's/OLD_THUMBPRINT/NEW_THUMBPRINT/g' \
       /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml
   ```

4. **Also update the node-level runtime manifest and settings:**

   ```bash
   # Find the data root
   # Ubuntu default: /mnt/sfroot
   # RedHat default: /mnt/resource/sfroot
   DATAROOT="/mnt/sfroot"
   if [ ! -d "$DATAROOT" ]; then
       DATAROOT="/mnt/resource/sfroot"
   fi

   # Update ClusterManifest.current.xml in each node folder
   find "$DATAROOT" -name "ClusterManifest.current.xml" -exec sudo cp {} {}.bak \;
   find "$DATAROOT" -name "ClusterManifest.current.xml" -exec sudo sed -i 's/OLD_THUMBPRINT/NEW_THUMBPRINT/g' {} \;

   # Update InfrastructureManifest.xml
   find "$DATAROOT" -name "InfrastructureManifest.xml" -exec sudo sed -i 's/OLD_THUMBPRINT/NEW_THUMBPRINT/g' {} \;

   # Update Settings.xml in the current Fabric.Config directory
   find "$DATAROOT" -path "*/Fabric/Fabric.Config.*/Settings.xml" -exec sudo sed -i 's/OLD_THUMBPRINT/NEW_THUMBPRINT/g' {} \;
   ```

5. **Restart SF processes:**

   ```bash
   # Preferred: use systemctl to restart SF services (modern clusters)
   sudo systemctl restart servicefabricnodebootstrapagent
   sudo systemctl restart servicefabric

   # Alternative: restart waagent which will re-trigger the bootstrap agent
   # sudo systemctl restart walinuxagent
   ```

   On modern clusters, restarting the systemd services directly is faster and more predictable. Restarting waagent triggers the SF extension, which starts the bootstrap agent, which starts FabricHost.

6. **Repeat on all nodes**, starting with seed nodes.

## [Quick Reference: Diagnostic Commands]

| Task | Command |
|------|---------|
| List all certs on node | `ls -la /var/lib/waagent/*.crt /var/lib/waagent/*.prv 2>/dev/null` |
| View cert thumbprint | `openssl x509 -in /var/lib/waagent/{THUMBPRINT}.crt -noout -fingerprint -sha1` |
| View cert expiry | `openssl x509 -in /var/lib/waagent/{THUMBPRINT}.crt -noout -dates` |
| View cert subject | `openssl x509 -in /var/lib/waagent/{THUMBPRINT}.crt -noout -subject` |
| Check manifest thumbprints (runtime) | `python3 -c "import xml.dom.minidom; print(xml.dom.minidom.parse('$(find /mnt/sfroot -name ClusterManifest.current.xml -print -quit 2>/dev/null)').toprettyxml())" \| grep -i thumbprint` |
| Check manifest thumbprints (staging) | `python3 -c "import xml.dom.minidom; print(xml.dom.minidom.parse('/var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/TempClusterManifest.xml').toprettyxml())" \| grep -i thumbprint` |
| Check extension settings | `cat $(ls -t /var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-*/config/*.settings \| head -1) \| python3 -m json.tool \| grep thumbprint` |
| Check waagent cert downloads | `grep -i "download.*cert\|cert.*download" /var/log/waagent.log` |
| Check waagent incarnation | `grep "incarnation" /var/log/waagent.log \| tail -5` |
| Check bootstrap agent errors | `grep -i "error\|fail\|FindKVVMExtCerts" /var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode/sfbootstrapagent_*.log \| tail -20` |
| Check syslog for SF | `grep -i "ServiceFabric\|fabric" /var/log/syslog \| tail -20` |
| Check heartbeat | `cat /var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-*/heartbeat.log` |
| Check extension install log | `cat /var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-*/ServiceFabricLinuxExtension_install.log` |
| Check SF data root | `ls /mnt/sfroot/ 2>/dev/null \|\| ls /mnt/resource/sfroot/ 2>/dev/null` |

## [Additional References]

- [Certificates and security on Linux clusters (MS Learn)](https://learn.microsoft.com/azure/service-fabric/service-fabric-configure-certificates-linux)
- [Manage certificates in Service Fabric clusters (MS Learn)](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificate-management)
- [Add or remove certificates for a Service Fabric cluster (MS Learn)](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-security-update-certs-azure)
- [Managing Azure Resources](../Deployment/managing-azure-resources.md)
- [Service Fabric Ubuntu File Locations](../Cluster/Service%20Fabric%20Ubuntu%20File%20Locations.md)
- [Service Fabric Red Hat File Locations](../Cluster/Service%20Fabric%20Red%20Hat%20File%20Locations.md)
- [Fix Expired Cluster Certificate Manual Steps (Windows)](./Fix%20Expired%20Cluster%20Certificate%20Manual%20Steps.md)
- [How to add and swap the Secondary Certificate (Windows)](./Use%20Azure%20Resource%20Explorer%20to%20add%20the%20Secondary%20Certificate.md)
- [Set up encryption certificate on Linux clusters (MS Learn)](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-secret-management-linux)
