# How to recover from an Expired CA signed Cluster Certificate

This article provides steps to recover from an expired Certificate Authority (CA) signed cluster certificate.  If the cluster is secured with a self-signed certificate declared by thumbprint, you can follow the simpler process outlined in [Fix Expired Cluster self-signed Certificate](../Security/How%20to%20recover%20from%20an%20Expired%20Cluster%20Certificate.md).  For CA issued certificates, continue with the steps outlined below. 

To prevent this issue in the future, consider using the CA signed certificate with cluster common name/issuer name configuration in combination with key vault virtual machine extension (kvvm). For more information, see [Manage certificates in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificate-management) and [Convert cluster certificates from thumbprint-based declarations to common names](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-change-cert-thumbprint-to-cn).

## [Symptom]  

* Cluster will show 'Upgrade Service not reachable' warning message
* Unable to see the SF Nodes in the Portal or SFX
* Error message related to Certificate in  '%SystemRoot%\System32\Winevt\Logs\Microsoft-ServiceFabric%4Admin.evtx'  event log from 'transport' resource

## [Verify Certificate Expired Status on Node]

* [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to any node
  * Open the Certificate Manager for 'Local Computer' (certlm.msc) and check below details
  * Make sure certificate is ACL'd to network service
  * Verify the Certificate Expiry, if it is expired, follow below steps
  ![](../media/certlm1.png)  
  ![](../media/certlm2.png)  

## [Fix Expired Cert steps]

1. Create new certificate to replace the expired certificate (choose one) if not already done:

   > a. Create with any reputable CA  
   > b. Generate self-signed certs using Azure Portal -> Key Vault.  
   > c. Create and upload using PowerShell - [CreateKeyVaultAndCertificateForServiceFabric.ps1](../Scripts/CreateKeyVaultAndCertificateForServiceFabric.ps1)

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

    > a. If the new certificate is in the **same Key Vault** as the Primary, add **"certificateUrl"** and **"certificateStore"** to existing array of **"vaultCertificates"** as shown below:

    ```json
      "virtualMachineProfile": {
        "osProfile": {
        …
          "secrets": [
            {
              "sourceVault": {
                "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sampleVaultGroup/providers/Microsoft.KeyVault/vaults/samplevault"
            },
            "vaultCertificates": [
              {
                "certificateUrl": "https://samplevault.vault.azure.net/secrets/clustercert001/d5eeaf025c7d435f81e7420393b442a9",
                "certificateStore": "My"
              },
              {
                "certificateUrl": "https://samplevault.vault.azure.net/secrets/clustercert002/77ff7688258a41f7b0afdd890eb4aa8c",
                "certificateStore": "My"
              }
            ]
          }
        ]
    ```

    > b. If the new certificate is in a **different Key Vault** as the Primary, add an additional secret to the array of **"secrets"** with **"sourceVault"** and **"vaultCertificates"** configuration as shown below:

    ```json
      "virtualMachineProfile": {
        "osProfile": {
        …
        "secrets": [
          {
            "sourceVault": {
              "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sampleVaultGroup/providers/Microsoft.KeyVault/vaults/samplevault"
            },
            "vaultCertificates": [
              {
                "certificateUrl": "https://samplevault.vault.azure.net/secrets/clustercert001/d5eeaf025c7d435f81e7420393b442a9",
                "certificateStore": "My"
              }
            ]
          },
          {
            "sourceVault": {
              "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sampleVaultGroup/providers/Microsoft.KeyVault/vaults/samplevault2"
            },
            "vaultCertificates": [
              {
                "certificateUrl": "https://samplevault2.vault.azure.net/secrets/clustercert002/77ff7688258a41f7b0afdd890eb4aa8c",
                "certificateStore": "My"
              }
            ]
          }
        ]
    ```

5. At top of page, click PUT.

    ![Click PUT](../media/resourcemgr7.png)

6. **Wait** for the virtual machine scale set Updating the secondary certificate to complete. At the top of page, click GET to check status. Verify "provisioningState" shows "Succeeded". If "provisioningState" equals "Updating", continue to periodically click GET at top of page to requery scale set.  If the cluster is configured with Silver or higher Durability it's possible a repair task may block this operation.  If the status does not move into a "Succeeded" state in a timely manner please contact Support for assistance to confirm and unblock.

    ![GET](../media/resourcemgr2.png)

    ![resources.azure.com vmss provisioningstate succeeded](../media/resourcemgr11.png)

7. The following needs to be performed on all nodes in all nodetypes by using [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to connect to each node in the cluster.

8. [On each node] Open Administrative powershell.exe

9. [On each node] Download [FixExpiredCert.ps1](../Scripts/FixExpiredCert.ps1) either to admin machine and copy to each node through RDP clipboard or download directly from within RDP session on node.

   Example of downloading from within RDP
  
    ```powershell
    $url = "https://raw.githubusercontent.com/Azure/service-fabric-scripts-and-templates/master/Scripts/FixExpiredCert.ps1"
    $output = "C:\FixExpiredCert.ps1"
    Invoke-WebRequest -Uri $url -OutFile $output
    ```

10. [On each node] Run the FixExpiredCert.ps1 script with the following cmd line passing both the expired certificate thumbprint and new active certificate thumbprint as shown in example below.

    ```powershell
    $oldThumbprint = "<replace with expired thumbprint>"
    $newThumbprint = "<replace with new thumbprint>"
    .\FixExpiredCert.ps1 -localOnly -oldThumbprint $oldThumbprint -newThumbprint $newThumbPrint
    ```

    Note: If there are any errors or issues when running the script you can attempt to fix\correct these and just rerun the script, changes made by the script are idempotent.  In some cases if there are many nodes and you know the mitigation was already successful on some nodes before the script failed then you can remove those from the nodeIpArray to speed things up, but there is no harm if the mitigation is run multiple times on the same node.

11. After step 10, services should be restarting and when ready you should able to reconnect to the cluster over SFX and PowerShell from a node in the cluster or your development computer. *(Make sure you have installed the new Cert to `CurrentUser\My`)*

    ```PowerShell
    $clusterName= "<clustername>.<cluster_region>.cloudapp.azure.com:19000"
    $certThumbprint = "<replace with clusterthumbprint>"
    import-module servicefabric
    Connect-ServiceFabricCluster -ConnectionEndpoint $clusterName -KeepAliveIntervalInSec 10 `
        -X509Credential `
        -ServerCertThumbprint $certThumbprint  `
        -FindType FindByThumbprint `
        -FindValue $certThumbprint `
        -StoreLocation CurrentUser `
        -StoreName My
    ```

    **Note**: Please give the cluster 5-10 minutes to reconfigure.  Generally speaking you will see Fabric.exe startup in the Task Manager and a few minutes later FabricGateway.exe will start when the nodes have finished reconfiguration.  At this point the cluster should be running using the new certificate and SFX endpoint and PowerShell endpoints should be accessible.

12. The cluster will not display Nodes or Applications or reflect the new Thumbprint yet because the Service Fabric Resource Provider (SFRP) record for this cluster has not be updated with the new thumbprint. **To correct this Contact Azure support to create a support ticket to request the final update to the SFRP record.**

13. The last step will be to update the cluster ARM template to reflect the location of the new Cert / Keyvault

    * Go to https://resources.azure.com --> Resource Group --> providers --> Microsoft.Compute --> vmss

    Ensure the correct KeyVault for the new cert is listed, update the "sourceVault" and "certificateUrl" properties

    ```json
                "secrets": [
                {
                    "sourceVault": {
                    "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/xxxxxx/providers/Microsoft.KeyVault/vaults/xxxxxxxx"
                    },
                    "vaultCertificates": [
                    {
                        "certificateUrl": "https://xxxxxx.vault.azure.net/secrets/xxxxxx/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
                        "certificateStore": "My"
                    }
                    ]
                }
    ```

    Update the "thumbprint" property with the new certificate thumbprint

    ```json
                "extensionProfile": {
                    "extensions": [
                    {
                        "properties": {
                        "autoUpgradeMinorVersion": true,
                        "settings": {
                            "clusterEndpoint": "https://xxxxx.servicefabric.azure.com/runtime/clusters/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                            "nodeTypeRef": "sys",
                            "dataPath": "D:\\\\SvcFab",
                            "durabilityLevel": "Bronze",
                            "enableParallelJobs": true,
                            "nicPrefixOverride": "10.0.0.0/24",
                            "certificate": {
                            "thumbprint": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                            "x509StoreName": "My"
                            }
    ```

