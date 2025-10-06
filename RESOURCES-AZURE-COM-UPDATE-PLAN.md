# Resources.Azure.Com Deprecation Update Plan

## Project Overview

This document tracks the comprehensive update of Service Fabric Troubleshooting Guides to replace deprecated `resources.azure.com` references with modern Azure Portal alternatives.

**Related Issues:**
- Issue #314: Resources.azure.com deprecation
- Issue #315: Add thumbprintSecondary to documentation
- PR #318: Draft with reference examples

**Reference Documents:**
- `Security/Fix Expired Cluster Certificate Automated Script.md` (already updated in PR #318)
- `Cluster/resource-explorer-steps.md` (comprehensive guide for alternatives)

**Replacement Pattern:**
Replace `https://resources.azure.com` with:
1. [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) - Read-only navigation
2. [API Playground](https://portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground) - For modifications
3. ARM Template export/deploy - For complex updates

---

## Files Requiring Updates (50+ references found)

### Priority 1: Security Documentation (High Impact)

#### 1. `Security/Fix Expired Cluster Certificate Manual Steps.md`
**Status:** Not Started
**References:** 3 instances
**Changes Needed:**
- Line 30: Replace resources.azure.com with Resource Explorer + API Playground workflow
- Line 117: Update screenshot reference (resourcemgr11.png may need updating)
- Line 225: Replace resources.azure.com reference with modern alternative
**Additional:**
- Add step-by-step navigation instructions matching PR #318 pattern
- Include screenshots similar to those in azure-resource-explorer-alternatives directory
- Add thumbprintSecondary references where appropriate (Issue #315)

#### 2. `Security/Use Azure Resource Explorer to add the Secondary Certificate.md`
**Status:** Not Started
**References:** 14 instances
**Changes Needed:**
- Title/header (line 3): Update to reflect new tools
- Throughout document: Replace all resources.azure.com references
- Lines 21, 146, 209, 264: Update navigation instructions
- Lines 140, 258: Update screenshot references
- Lines 318-324: Update error handling section for API Playground
- Complete rewrite of workflow sections to match PR #318 pattern
**Additional:**
- This is essentially the same as "Fix Expired Cluster Certificate" but for secondary certs
- Should follow very similar pattern to Automated Script.md
- Add comprehensive Resource Explorer + API Playground instructions
- Verify and update all screenshots

#### 3. `Security/How to recover from an Expired Cluster Certificate.md`
**Status:** Not Started
**References:** 2 instances
**Changes Needed:**
- Line 31: Replace resources.azure.com with API Playground instructions
- Line 121: Update reference to use modern tools
- Add AcceptExpiredPinnedClusterCertificate update instructions using new tools
**Additional:**
- Add thumbprintSecondary references (Issue #315)
- Ensure consistency with other certificate recovery documents

#### 4. `Security/README.md`
**Status:** Not Started
**References:** 1 instance
**Changes Needed:**
- Line 14: Update link text and possibly retitle the linked document
**Additional:**
- Review entire security section for consistency

#### 5. `Security/DSC - ACL a certificate using Desired State Configuration.md`
**Status:** Not Started
**References:** 1 instance (appears twice in line)
**Changes Needed:**
- Line 23: Replace resources.azure.com reference
**Additional:**
- Review context to determine if detailed instructions needed or just reference link

#### 6. `Security/Swap Reverse Proxy certificate.md`
**Status:** Not Started
**References:** 1 instance
**Changes Needed:**
- Line 18: Replace resources.azure.com with Resource Explorer + API Playground
- Add navigation instructions
**Additional:**
- Add thumbprintSecondary if applicable (Issue #315)

#### 7. `Security/Removing a Secondary certificate with expiry date later than Primary certificate expiry date.md`
**Status:** Not Started
**References:** 2 instances
**Changes Needed:**
- Line 13: Replace resources.azure.com reference
- Line 25: Update NOTE to reference new tools
- Update ARM template instructions to include API Playground option
**Additional:**
- Add thumbprintSecondary references (Issue #315)

#### 8. `Security/How to Configure a Service Fabric Managed Cluster with Common Name Certificate.md`
**Status:** Not Started
**References:** 3 instances
**Changes Needed:**
- Line 37: Replace resources.azure.com navigation instructions
- Line 113: Replace resources.azure.com navigation for nodetype
- Line 244: Update verification instructions
**Additional:**
- Verify managed cluster specific considerations
- Add link to resource-explorer-steps.md

### Priority 2: Cluster Documentation

#### 9. `Cluster/How to fix missing seednodes with Automated script.md`
**Status:** Not Started
**References:** 3 instances
**Changes Needed:**
- Lines 72, 143: Replace resources.azure.com references in instructions
- Line 173: Update VM instance count increase instructions
**Additional:**
- Add Resource Explorer + API Playground workflow
- Include screenshots if detailed instructions needed

#### 10. `Cluster/How to Fix one missing seed node.md`
**Status:** Not Started
**References:** 3 instances
**Changes Needed:**
- Lines 75, 188: Replace resources.azure.com references
- Line 210: Update VM instance count increase instructions
**Additional:**
- Ensure consistency with automated script document

#### 11. `Cluster/How to Fix two missing seed node.md`
**Status:** Not Started
**References:** 3 instances
**Changes Needed:**
- Lines 77, 217: Replace resources.azure.com references
- Line 247: Update VM instance count increase instructions
**Additional:**
- Ensure consistency with other seed node documents

#### 12. `Cluster/How to Rotate Access Keys of Storage Account for Service Fabric logs.md`
**Status:** Not Started
**References:** 4 instances
**Changes Needed:**
- Line 5: Update introduction to reference new tools
- Line 12: Update method reference
- Line 187: Update section header
- Line 193: Complete navigation instructions section
- Line 263: Update screenshot reference
**Additional:**
- May need new screenshots for API Playground workflow
- Add complete alternative workflow section

### Priority 3: Known Issues Documentation

#### 13. `Known_Issues/All VMSS operations are blocked on Silver or higher durability.md`
**Status:** Not Started
**References:** 1 instance
**Changes Needed:**
- Line 79: Replace resources.azure.com with API Playground reference
**Additional:**
- Brief update, likely just reference change

#### 14. `Known_Issues/Service Fabric 7.1 High CPU Fabric.exe One Node.md`
**Status:** Not Started
**References:** 1 instance
**Changes Needed:**
- Line 44: Replace resources.azure.com with modern alternative
- Update link to appropriate documentation
**Additional:**
- Verify Service Fabric version specific considerations

#### 15. `Known_Issues/Service Fabric 9.x Repair Job Stuck.md`
**Status:** Not Started
**References:** 1 instance
**Changes Needed:**
- Line 72: Replace resources.azure.com with API Playground
**Additional:**
- Brief update

---

## Additional Files to Check

Need to verify if there are additional files beyond the 50 matches shown. Run comprehensive search for:
- `resources.azure.com`
- `resource explorer` (case insensitive)
- ARM template modification patterns
- Certificate thumbprint references for Issue #315

---

## Standard Replacement Pattern

**Reference:** See complete before/after in:
- Git diff: `git diff master...resources-azure-com-doc-updates -- "Security/Fix Expired Cluster Certificate Automated Script.md"`
- Current branch file: `Security/Fix Expired Cluster Certificate Automated Script.md`

### Before (Old Pattern):
```markdown
2. Deploy new cert to all nodes in VMSS, go to <https://resources.azure.com>, navigate to the virtual machine scale set configured for the cluster:

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

    ![Azure Resource Explorer](../media/resourcemgr1.png)

3. Click "Read/Write" permission and "Edit" to edit configuration.

    ![Read/Write](../media/resourcemgr3.png)
    ![Edit](../media/resourcemgr2.png)

4. Modify **"virtualMachineProfile / osProfile / secrets"**, to add (deploy) the new certificate to each of the nodes in the nodetype. Choose one of the options below:

[...JSON examples...]

5. At top of page, click PUT.

    ![Click PUT](../media/resourcemgr7.png)

6. **Wait** for the virtual machine scale set Updating the secondary certificate to complete. At the top of page, click GET to check status. Verify "provisioningState" shows "Succeeded". If "provisioningState" equals "Updating", continue to periodically click GET at top of page to requery scale set. If the cluster is configured with Silver or higher Durability it's possible a repair task may block this operation.

    ![GET](../media/resourcemgr2.png)
    ![resources.azure.com vmss provisioningstate succeeded](../media/resourcemgr11.png)
```

### After (New Pattern):
```markdown
1. Go to [Resource Explorer](https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade) in [Azure Portal](https://portal.azure.com/) and navigate to the virtual machine scale set configured for the cluster:

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

2. To modify this resource, triple-click to copy the complete resource URI with API version from the read-only box to the right of the `Open Blade` button for modification using [`API Playground`](https://portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground) as described below. Example:

   ![Resource Explorer](../media/resource-explorer-steps/portal-resource-explorer-vmss-resource-highlight.png)

3. Navigate to [API Playground](https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground) in [Azure Portal](https://portal.azure.com/) and paste the copied resource URI with API version from Resource Explorer into the input box to the right of the HTTP Request Method.

4. Select `Execute` to view the configuration of the specified resource.

5. The `Response Body` will display the configuration of the resource similar to the Resource Explorer view. This response body can be copied and pasted into `Request Body` field above to modify the configuration.

6. Set the request method to `PUT`, select `Request Body`, and paste the copied response body.

7. Modify the configuration as needed.

8. Select `Execute` to modify the configuration. In the `Response Body`, verify that `Status Code` is '200' and `provisioningState` is 'Updating' or 'Succeeded'.

9. The provisioning status can be monitored in the [Azure Portal](https://portal.azure.com/) or by performing additional `Get` requests from [API Playground](https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground).
```

### For Cluster Resources:
Replace `Microsoft.Compute/virtualMachineScaleSets` with `Microsoft.ServiceFabric/clusters` and use cluster-specific screenshots.

---

## ThumbprintSecondary Updates (Issue #315)

In all certificate-related documentation, ensure both `thumbprint` and `thumbprintSecondary` are referenced where applicable:

### Pattern:
```json
"certificate": {
  "thumbprint": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "thumbprintSecondary": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
  "x509StoreName": "My"
}
```

### Files to update:
- All files in Security/ folder dealing with certificates
- Specifically those updated for resources.azure.com replacement
- Any JSON examples showing certificate configuration

---

## Media/Screenshots Required

Based on PR #318, the following screenshots may need to be created or are already available:
- ✅ `portal-resource-explorer-vmss-resource-highlight.png`
- ✅ `api-playground-vmss-get.png`
- ✅ `api-playground-vmss-put-updating.png`
- ✅ `portal-resource-explorer-cluster-resource-highlight.png`
- ✅ `api-playground-cluster-get.png`
- ✅ `api-playground-cluster-put.png`
- ✅ `api-playground-cluster-put-response.png`
- 🔲 Additional screenshots may be needed for specific scenarios

---

## Grammar and Style Guidelines

From completed PR #318 review:
- ✅ Standardize "Key Vault" (not "KeyVault")
- ✅ Standardize "node type" (not "nodetype")
- ✅ Use "the following" instead of "below" when referencing lists
- ✅ Use "using the same steps" not "using same steps"
- ✅ Proper comma usage in complex sentences
- ✅ Consistent heading capitalization
- ✅ Remove extra spaces in paths and references

---

## Commit Strategy

1. Commit each major document individually after completion
2. Use descriptive commit messages:
   - "Update [filename] for resources.azure.com deprecation #314"
   - "Add thumbprintSecondary to [filename] #315"
3. Final commit: "Complete resources.azure.com deprecation updates"

---

## Testing Checklist

For each updated file:
- [ ] All resources.azure.com references replaced
- [ ] Navigation instructions match PR #318 pattern
- [ ] Screenshots are current and correctly referenced
- [ ] Links are functional
- [ ] Grammar and style guidelines followed
- [ ] ThumbprintSecondary added where applicable
- [ ] Cross-references to resource-explorer-steps.md added
- [ ] JSON examples are valid and formatted
- [ ] Markdown syntax is correct

---

## Timeline Estimate

- **Priority 1 (Security):** 8 files - Estimated 6-8 hours
- **Priority 2 (Cluster):** 4 files - Estimated 2-3 hours
- **Priority 3 (Known Issues):** 3 files - Estimated 1-2 hours
- **Review and Testing:** 2-3 hours
- **Total:** 11-16 hours

---

## Notes

- PR #318 provides excellent template for detailed updates
- resource-explorer-steps.md is comprehensive reference
- Some files may require less detailed updates (just link to alternatives doc)
- Consider creating a single detailed example and linking to it from simpler updates
- Verify managed cluster considerations separately from classic clusters

---

## Status Legend

- ✅ Complete
- 🔄 In Progress
- 🔲 Not Started
- ⚠️ Blocked/Issue
- 📝 Needs Review
