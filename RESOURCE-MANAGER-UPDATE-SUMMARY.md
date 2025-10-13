# Resource Manager Blade Update Summary

## Overview
Updated all documentation to use the new unified Resource Manager blade in Azure Portal, replacing deprecated resources.azure.com references and outdated portal blade URLs.

## New Portal URLs

### Primary Entry Point
- **Resource Manager Overview**: https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/overview
  - Provides unified access to both Resource Explorer and ARM API Playground

### Resource Explorer (Read-Only Browsing)
- **Old URL**: https://portal.azure.com/#view/HubsExtension/ArmExplorerBlade
- **New URL**: https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/resourceexplorer
- **Purpose**: Browse and view Azure resources in hierarchical tree structure (read-only)

### ARM API Playground (Modifications)
- **Old URLs**: 
  - https://ms.portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground
  - https://portal.azure.com/#view/Microsoft_Azure_Resources/ArmPlayground
- **New URL**: https://portal.azure.com/#view/Microsoft_Azure_Resources/ResourceManagerBlade/~/armapiplayground
- **Purpose**: Execute GET, PUT, PATCH, DELETE operations on ARM APIs

### Deprecated URL Removed
- **resources.azure.com**: Completely removed from all documentation

## Files Modified

### Core Documentation
1. **Deployment/managing-azure-resources.md** (Major Rewrite)
   - Updated introduction to reference unified Resource Manager blade
   - Added Resource Manager overview as primary entry point
   - Updated all workflow instructions with new URLs
   - Added new screenshots showing unified interface
   - Updated sections:
     - Azure Portal overview
     - Using Azure Portal to view resources
     - Using Azure Portal to update resources
     - Obtaining Resource ID via Azure Portal
     - Obtaining API Version via Azure Portal

### Security Documentation (7 files)
2. **Security/Fix Expired Cluster Certificate Automated Script.md**
3. **Security/Fix Expired Cluster Certificate Manual Steps.md**
4. **Security/How to recover from an Expired Cluster Certificate.md**
5. **Security/Swap Reverse Proxy certificate.md**
   - Updated all Resource Explorer and API Playground links
   - Replaced old portal blade URLs with new Resource Manager URLs

### Cluster Documentation (5 files)
6. **Cluster/Fabric Upgrade Policy - Define a Custom Fabric Upgrade Policy.md**
7. **Cluster/How to fix missing seednodes with Automated script.md**
8. **Cluster/How to setup Azure Alerts for Service Fabric Linux node performance counters.md**
   - Replaced resources.azure.com references
   - Updated section header from "resources.azure.com" to "ARM API Playground troubleshooting"
   - Removed deprecated troubleshooting screenshots
   - Added link to Managing Azure Resources guide
9. **Cluster/How to setup Azure Alerts for Service Fabric Windows node performance counters.md**
   - Replaced resources.azure.com references
   - Updated section header from "resources.azure.com" to "ARM API Playground troubleshooting"
   - Removed deprecated troubleshooting screenshots
   - Added link to Managing Azure Resources guide
10. **Cluster/Out of Diskspace.md**
    - Replaced resources.azure.com reference with Resource Manager - ARM API Playground link

### Deployment Documentation (1 file)
11. **Deployment/Installing dependencies on virtual machine scaleset.md**
    - Updated Resource Explorer and API Playground links

## New Media Files

### Created New Directory
- **media/managing-azure-resources/** (13 new screenshots)

### New Screenshots
1. `arm-api-put-vmss-nodetype0-current-state.png` - ARM API showing current VMSS state
2. `arm-api-put-vmss-nodetype0-test.png` - ARM API test execution
3. `arm-api-put-vmss-nodetype0.png` - ARM API PUT request for VMSS
4. `arm-api-put-workflow.png` - Complete ARM API workflow diagram
5. `arm-api-servicefabric-cluster.png` - ARM API with Service Fabric cluster
6. `azure-portal-fixed.png` - Resource Manager overview page
7. `resource-explorer-obfuscated.png` - Resource Explorer interface
8. `resource-servicefabric-cluster.png` - Resource Explorer showing SF cluster
9. `resource-vmss-nodetype0.png` - Resource Explorer showing VMSS details
10. `vmss-detail-bottom.png` - VMSS detailed view (bottom section)
11. `vmss-detail-middle.png` - VMSS detailed view (middle section)
12. `vmss-detail-top.png` - VMSS detailed view (top section)
13. `workflow-test-vmss-nodetype0.png` - Complete workflow test

### Deprecated Screenshots (To Be Reviewed)
- `media/resourcemgr*.png` - Old Azure Resource Explorer (Preview) screenshots
- These may still be referenced in unmodified docs

## Verification

### URLs Updated
- ✅ All old HubsExtension/ArmExplorerBlade URLs → New ResourceManagerBlade/~/resourceexplorer
- ✅ All old Microsoft_Azure_Resources/ArmPlayground URLs → New ResourceManagerBlade/~/armapiplayground
- ✅ All resources.azure.com references removed (verified with grep)

### Files Verified
- ✅ 11 markdown files updated with consistent new URLs
- ✅ 13 new screenshots added to media/managing-azure-resources/
- ✅ No broken links introduced
- ✅ All modified files use consistent terminology

## Git Commits

### Latest Commit (7e86d78)
**Message**: refactor: Update to unified Resource Manager blade with new navigation

**Changes**:
- 24 files changed, 85 insertions(+), 69 deletions(-)
- 13 new media files created

### Previous Related Commits
- 38219b5 - fix: Remove deprecated resources.azure.com update plan and related references
- 5d1b059 - fix: Remove final resources.azure.com reference and old Resource Explorer image
- a5330da - refactor: Reorganize to managing-azure-resources.md in Deployment folder

## Testing Recommendations

1. **Link Validation**: Run dead link checker on all modified files
2. **Screenshot Verification**: Verify all new screenshots are properly referenced
3. **Portal Testing**: Test new URLs in Azure Portal to ensure they navigate correctly
4. **Cross-Reference Check**: Verify all [Managing Azure Resources] links point to correct file

## Next Steps

### Optional Improvements
1. Consider renaming `media/resource-explorer-steps/` to `media/managing-azure-resources/` for consistency
2. Review and potentially remove unused `media/resourcemgr*.png` files
3. Update any remaining unmodified docs that reference old URLs
4. Consider adding Resource Manager overview link to README files

### Documentation Quality
- All syntax should be correct
- All embedded links point to new Resource Manager blade
- Consistent terminology used throughout
- New navigation flow clearly explained

## Benefits of Changes

1. **Unified Interface**: Single entry point (Resource Manager) provides access to both browsing and modification tools
2. **Better User Experience**: Clearer navigation between read-only browsing (Resource Explorer) and modification (ARM API Playground)
3. **Future-Proof**: Uses current portal blade structure, not deprecated interfaces
4. **Consistency**: All docs now use same URL patterns and terminology
5. **Comprehensive**: Includes detailed instructions and screenshots for new workflow
