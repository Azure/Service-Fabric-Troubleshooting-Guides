# Collecting logs for failed VMs

## Overview

This article provides guidance on collecting logs for Virtual Machines (VMs) in a Failed (Running) state in Azure Portal. This situation can prevent Service Fabric nodes from becoming healthy.

## Symptoms

VMs in a Virtual Machine Scale Set (VMSS) are in a Failed (Running) state, which prevents Service Fabric nodes from becoming healthy. Although the VMs are running, there is an error in one of the VMSS extensions. The VMs will still be accessible through Remote Desktop Protocol (RDP).

## Root Causes

Several reasons may cause a VMSS extension to fail:

*   Incorrect VMSS extension configuration.
*   A resource referenced by the VMSS extension is not available.
*   Network connectivity
*   Timeouts or transient issues causing the extensions to fail.

## Scoping Questions

To narrow down the problem, consider asking:

1.  Are all VMs experiencing this issue, or only certain ones?
2.  Has there been any recent changes to Extension configurations or resources?
3.  Are there specific error messages related to the failure of VMSS extensions?
4.  Have any recent OS updates been made?
5.  Have any recent NSG updates been made?

## Data Collection

To gather data necessary for troubleshooting:

1.  RDP into one or more of the VMs in a Failed state.
2.  Open Command Prompt and run the following commands:
    
    ```cmd
    md C:\guestlogs
    cd C:\guestlogs
    C:\WindowsAzure\GuestAgent_VERSION\CollectGuestLogs.exe 
    ```
    
    Replace `VERSION` with the highest version value available.
    
3.  This command creates a compressed file with various logs.
4.  Copy this file out of the VM.

## Troubleshooting Steps

1.  **Check Configuration Issues:**
    *   Review failures in the logs to identify any configuration issues like invalid references to resources.
    *   Correct any configuration errors found in your Azure Resource Manager (ARM) template and redeploy it.
2.  **Address Other Issues:**
    *   If no configuration issues are identified, open a support incident through Azure Portal.
    *   Include collected logs from affected VMs or error messages found within these logs.

## Preventive Measures

To avoid similar issues in future:

*   Regularly validate and update your ARM templates and configurations.
*   Ensure that all resources referenced by VMSS extensions are available and correctly configured.
*   Monitor VMSS extensions for timeouts and transient issues proactively.

## Contact Information

For further assistance or escalation, contact Microsoft Support through \[Azure Portal\].

## References

N/A
