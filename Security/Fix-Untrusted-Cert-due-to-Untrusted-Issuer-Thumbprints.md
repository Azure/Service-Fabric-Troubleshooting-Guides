# Cluster Outage due to Introduction of a Cluster Certificate whose Direct Issuing CA is not Trusted

## Is this the right TSG?

- Cluster is using common name-based certificate declarations with issuer thumbprint pinning -- See [document](https://docs.microsoft.com/azure/service-fabric/cluster-security-certificates#common-name-based-certificate-validation-declarations)
- You are unable to reach the cluster; or many nodes are down; or on nodes FabricGateway.exe is not running

It is possible that you have recently rotated the cluster certificate. Though the new certificate is a common-name-match, it was issued by a CA whose thumbprint is NOT pinned, and hence not trusted in the cluster.

1. Identify the current cluster certificate and its direct issuing CA's thumbprint
    1. If a certificate is being presented on 19080 (Service Fabric Explorer), inspect the certificate using your browser. This is the target certificate.
    1. If not, RDP onto a cluster node. Gather the list of all certificates in  LocalMachine/My which are a common name match to your cluster configuration. If you are running Service Fabric version 7.2.445 (7.2 CU4) or higher, select the certificate with this common name that has the largest NotBefore date (most recently issued). If on a prior SF version, select the certificate with the largest NotAfter date (furthest from expiring). This is the target certificate.
    1. Was this certificate recently issued? If the certificate was not recently issued, rotation likely did not happen recently, and the true problem might be elsewhere.
    1. Inspect this certificate by opening it, click "Certification Path", double-click on the certificate directly above the leaf in the chain, click details, and click Thumbprint. This is the thumbprint of the direct issuer.
    1. If you are unable to use the certificate interface, you can fetch the issuer thumbprint using the following script, run from an admin powershell window:

```powershell
$thumbprint = "<leaf certificate SHA-1 thumbprint>"
$cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object {$_.Thumbprint -match $thumbprint}
$certChain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
$certChain.Build($cert)
($certChain.ChainElements.Certificate | Where-Object {$_.Subject -eq $cert.Issuer}).Thumbprint
```

2. Is the issuer thumbprint missing from the list of pinned issuers in the cluster manifest? If it is missing, this is the appropriate TSG.

## Mitigation 1: Fallback to a good certificate

Since this certificate recently rotated, there is a good chance the prior cluster certificate is still time-valid, and was issued by a CA which is trusted by the cluster. You should inspect this certificate (the certificate with the correct common name and the second largest NotBefore date -- if on 7.2 CU4+), and validate if this is the case.

If it is not valid or its issuer is not trusted, move onto Mitigation 2.

If both are true, you can try to help the cluster fallback to this certificate. This is accomplished by:

1. Disabling the provisioning of the newer certificate
1. Deleting the newer certificate from all nodes

### Disabling the provisioning of the newer certificate

There are two common patterns used in Azure to provision certificates onto nodes:

1. VMSS is using the Key Vault VM Extension to provision certificates
    1. To disable provisioning of the new certificate, disable the certificate in Key Vault
2. VMSS has the certificate declared in its OS Profile
    1. Generally it is difficult to adequately disable this method while a cluster is down. However, it is possible to proceed with deleting certificates from nodes, as long as it is understood that they may be re-provisioned randomly onto the nodes. It is much safer to move to Mitigation 2

Once the certificate has been disabled. Begin to delete this certificate on every node by RDP-ing into each node. Pay careful attention to guarantee the right certificate is being deleted, and know that if this certificate is in use elsewhere besides the Service Fabric cluster, those services will lose access to the certificate. Once the certificate has been deleted on all nodes, give the cluster 10 minutes, and it should begin to restore.

## Mitigation 2: Patching the trusted issuer thumbprint list

This mitigation involves a form of brain surgery to change the fundamental definition of the cluster on every node to trust the new issuer thumbprint. There is no form of safe brain surgery, and brain surgery carries risk to permanently alter the stability of the cluster or make it more difficult to recover.

[A script is provided to perform the brain surgery, it should be run from a node which is part of the cluster.](../Scripts/PatchIssuerThumbprints.ps1) All nodes need to have the script run on them, though the script can be deployed throughout the cluster from a single run point.

It can be run using
```powershell

.\PatchIssuerThumbprints.ps1
    -clusterDataRootPath "D:\SvcFab"
    -targetIssuerThumbprints "<thumbprint>,<thumbprint>,<thumbprint>"
    -nodeIpArray @("10.0.0.4", "10.0.0.5", "10.0.0.6" ),
    -cacheCredentials
    -localOnly
    -hard
```

- `clusterDataRootPath`: Generally D:\SvcFab on azure nodes, but could be anyway as configured
- `targetIssuerThumbprints`: A string which is a comma-delimited list of SHA-1 thumbprints. This list should include the entire set of issuers which should be trusted. For example, if 2 thumbprints are trusted and a third needs to be added, this list should include all 3 thumbprints.
- `nodeIpArray`: if not using "localonly", the list of all node ips which script should be run against. Generally these are the private ips, as script is run from within vnet
- `cacheCredentials`: whether to cache RDP credentials between multiple runs
- `localOnly`: whether the script should only be run on the node where it script is called. It can also be used to run on each node when there are connectivity issues between nodes.
- `hard`: switch to change the patch style. Default is a soft patch, which is meant to keep the logical node processes, Fabric, FabricHost from closing. Soft patches do not change the fundamental node definition, so a cluster upgrade must be pushed soon after cluster health is restored. Soft patches may need to be run multiple times as nodes regress to their previous definition. A hard patch will change the fundamental node definition, but a cluster upgrade should still be pushed soon after cluster health is restored. Hard patches guarantee that fabric logical node will close, cluster availability loss is all but guaranteed, if not already being experienced. In general hard patches are much less likely to regress on their own

It is important to note that it is safe to run the same script multiple times against a node.

## Mitigation 3: Issuer a newer certificate from a trusted issuer

This solution depends greatly on the nature and situation of the CA and PKI. However, if it is possible to issue one or more new certificates with the appropriate common name, they can be issued until one is issued by a direct issuing CA which is already trusted in the cluster. If a certificate can be obtained which is a better match than the current bad certificate (more recently issued from 7.2 CU4+ or longer living on early SF versions), this certificate can be manually installed on all nodes, and the cluster should switch to using this certificate.
