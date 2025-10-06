# Quick Reference: resources.azure.com Replacement Patterns

## Source Reference
Based on completed work in branch `resources-azure-com-doc-updates`:
- File: `Security/Fix Expired Cluster Certificate Automated Script.md`
- View diff: `git diff master...resources-azure-com-doc-updates -- "Security/Fix Expired Cluster Certificate Automated Script.md"`

---

## Key Transformations

### 1. Replace resources.azure.com URL

**BEFORE:**
```markdown
go to <https://resources.azure.com>, navigate to...
```

**AFTER:**
```markdown
Go to [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) in [Azure Portal](https://portal.azure.com/) and navigate to...
```

---

### 2. Navigation Instructions

**BEFORE:**
```markdown
    subscriptions
    └───%subscription name%
        └───resourceGroups
            └───%resource group name%
                └───providers
                    └───Microsoft.Compute
                        └───virtualMachineScaleSets
                            └───%virtual machine scale set name%

![Azure Resource Explorer](../media/resourcemgr1.png)
```

**AFTER:**
```markdown
   ```text
   subscriptions
   └───%subscription name%
       └───resourceGroups
           └───%resource group name%
               └───providers
                   └───Microsoft.Compute
                       └───virtualMachineScaleSets
                           └───%virtual machine scale set name%
   ```
```

---

### 3. Edit Instructions (resources.azure.com had Read/Write + Edit buttons)

**BEFORE:**
```markdown
3. Click "Read/Write" permission and "Edit" to edit configuration.

    ![Read/Write](../media/resourcemgr3.png)
    ![Edit](../media/resourcemgr2.png)
```

**AFTER:**
```markdown
3. To modify this resource, triple-click to copy the complete resource URI with API version from the read-only box to the right of the `Open Blade` button for modification using [`API Playground`](https://portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground) as described below. Example:

   ![Resource Explorer](../media/resource-explorer-steps/portal-resource-explorer-vmss-resource-highlight.png)

4. Navigate to [API Playground](https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground) in [Azure Portal](https://portal.azure.com/) and paste the copied resource URI with API version from Resource Explorer into the input box to the right of the HTTP Request Method.

5. Select `Execute` to view the configuration of the specified resource.

6. The `Response Body` will display the configuration of the resource similar to the Resource Explorer view. This response body can be copied and pasted into `Request Body` field above to modify the configuration. Example:

   ![Resource Explorer](../media/resource-explorer-steps/api-playground-vmss-get.png)

7. Set the request method to `PUT`, select `Request Body`, and paste the copied response body.
```

---

### 4. PUT/Submit Instructions

**BEFORE:**
```markdown
5. At top of page, click PUT.

    ![Click PUT](../media/resourcemgr7.png)
```

**AFTER:**
```markdown
9. Select `Execute` to modify the configuration. In the `Response Body`, verify that `Status Code` is '200' and `provisioningState` is 'Updating' or 'Succeeded'. Example:

   ![Resource Explorer](../media/resource-explorer-steps/api-playground-vmss-put-updating.png)
```

---

### 5. GET/Check Status Instructions

**BEFORE:**
```markdown
6. **Wait** for the virtual machine scale set Updating the secondary certificate to complete. At the top of page, click GET to check status. Verify "provisioningState" shows "Succeeded". If "provisioningState" equals "Updating", continue to periodically click GET at top of page to requery scale set. If the cluster is configured with Silver or higher Durability it's possible a repair task may block this operation.

    ![GET](../media/resourcemgr2.png)
    ![resources.azure.com vmss provisioningstate succeeded](../media/resourcemgr11.png)
```

**AFTER:**
```markdown
10. **Wait** for the virtual machine scale set `ProvisioningStatus` value "Succeeded" for the certificate update as shown above. The provisioning status can be monitored in the [Azure Portal](https://portal.azure.com/) or by performing additional `Get` requests from [API Playground](https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground). If "provisioningState" equals "Updating", continue to periodically click GET at top of page to requery scale set.

> [!NOTE]
> If the cluster is configured with Silver or higher Durability, the repair task will be blocked. Contact Microsoft Support for assistance with unblocking tenantupdate job.
```

---

### 6. Terminology Updates

| Before | After |
|--------|-------|
| `KeyVault` | `Key Vault` |
| `nodetype` | `node type` |
| `check below details` | `check the following details` |
| `follow below steps` | `follow the steps below` |
| `using same steps` | `using the same steps` |
| `kvvm` (lowercase) | `KVVM` (uppercase acronym) |
| `fix\correct` | `fix/correct` |

---

### 7. Screenshot References

**Old screenshots to replace:**
- `../media/resourcemgr1.png` → Remove or use new Resource Explorer screenshot
- `../media/resourcemgr2.png` → Remove (old Edit button)
- `../media/resourcemgr3.png` → Remove (old Read/Write button)
- `../media/resourcemgr7.png` → Remove (old PUT button)
- `../media/resourcemgr11.png` → Can reference but may need update

**New screenshots available:**
- `../media/resource-explorer-steps/portal-resource-explorer-vmss-resource-highlight.png`
- `../media/resource-explorer-steps/api-playground-vmss-get.png`
- `../media/resource-explorer-steps/api-playground-vmss-put-updating.png`
- `../media/resource-explorer-steps/portal-resource-explorer-cluster-resource-highlight.png`
- `../media/resource-explorer-steps/api-playground-cluster-get.png`
- `../media/resource-explorer-steps/api-playground-cluster-put.png`
- `../media/resource-explorer-steps/api-playground-cluster-put-response.png`

---

### 8. Add thumbprintSecondary (Issue #315)

**BEFORE:**
```json
"certificate": {
  "thumbprint": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "x509StoreName": "My"
}
```

**AFTER:**
```json
"certificate": {
  "thumbprint": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "thumbprintSecondary": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
  "x509StoreName": "My"
}
```

---

### 9. Add Reference Links

Add at end of document:

```markdown
## Reference

[Manage certificates in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificate-management)

[X.509 Certificate-based authentication in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificates)

[Azure Resource Explorer Alternatives](../Cluster/resource-explorer-steps.md)
```

---

### 10. Improve Section Headers

**BEFORE:**
```markdown
## [Fix Expired Cert steps]
```

**AFTER:**
```markdown
## [Fix Expired Cert steps]
```
(Keep consistent with existing style, but ensure proper capitalization)

---

### 11. Better Notes/Warnings

Use modern markdown alert syntax:

```markdown
> [!NOTE]
> Important note text here

> [!IMPORTANT]
> Critical information here

> [!WARNING]
> Warning text here
```

---

## Cluster Resource Pattern

For Service Fabric Cluster resources (not VMSS), use:

```markdown
Navigate to [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) in [Azure Portal](https://portal.azure.com/) and navigate to the cluster resource:

   ```text
   subscriptions
   └───%subscription name%
       └───resourceGroups
           └───%resource group name%
               └───providers
                   └───Microsoft.ServiceFabric
                       └───clusters
                           └───%cluster name%
   ```
```

Use cluster-specific screenshots:
- `portal-resource-explorer-cluster-resource-highlight.png`
- `api-playground-cluster-get.png`
- `api-playground-cluster-put.png`

---

## Quick Find & Replace Patterns

Safe global replacements (but verify context):

1. `https://resources.azure.com` → `[Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade)`
2. `resources.azure.com` → `Resource Explorer or API Playground`
3. `KeyVault` → `Key Vault`
4. `nodetype` → `node type` (where used as two words)
5. `check below` → `check the following`
6. `follow below steps` → `follow the steps below`

**DO NOT** blindly replace - always check context!

---

## When to Use Brief vs Detailed Instructions

### Brief (link to alternatives doc):
- Simple one-time references
- Already explained elsewhere in document
- Known Issues section

Example:
```markdown
Update the configuration using [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) or [API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground). For detailed instructions, see [Azure Resource Explorer Alternatives](../Cluster/resource-explorer-steps.md).
```

### Detailed (full workflow):
- Main procedure documents
- First-time users
- Complex multi-step processes
- Certificate-related security docs

Use the full pattern from Fix Expired Cluster Certificate Automated Script.md

---

## Testing Checklist for Each File

- [ ] All `resources.azure.com` URLs replaced
- [ ] Navigation uses proper code block formatting
- [ ] Screenshots updated or removed appropriately
- [ ] API Playground workflow added where needed
- [ ] `thumbprintSecondary` added to certificate examples
- [ ] Terminology standardized (Key Vault, node type, etc.)
- [ ] Grammar improvements applied
- [ ] Reference links added
- [ ] Markdown linting passes
- [ ] Links are functional

---

## Commit Message Template

```
Update [filename] for resources.azure.com deprecation #314

- Replace resources.azure.com with Resource Explorer + API Playground
- Add detailed navigation and modification instructions
- Update screenshots to current Azure Portal interface
- Add thumbprintSecondary to certificate examples #315
- Standardize terminology and improve grammar
- Add reference to resource-explorer-steps.md
```

---

**Last Updated:** Based on PR #318 draft changes
**Reference Branch:** resources-azure-com-doc-updates

