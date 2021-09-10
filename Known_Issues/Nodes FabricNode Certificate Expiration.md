# FabricNode Certificate Expiration

[Issue](#Issue)  
[Health State](#Health-State)  
[Description](#Description)  
[Cause](#Cause)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  
[Reference](#Reference)  

## Issue

Service Fabric Cluster Nodes Health Events Warnings for cluster, server, and client certificates.

## Health State

Warning

## Description

```text
System.FabricNode	Certificate_cluster	Mon, 11 May 2020 08:43:09 GMT	Infinity	132336601893388932	false	false
Certificate expiration: thumbprint = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, 
expiration = 2020-06-07 18:22:33.000, 
remaining lifetime is 27:9:39:23.661, 
please refresh ahead of time to avoid catastrophic failure. 
Warning threshold Security/CertificateExpirySafetyMargin is configured at 30:0:00:00.000, 
if needed, you can adjust it to fit your refresh process.
```

## Cause

A warning will be displayed when certificate expiration time is below threshold. Default threshold is 30 days.

**NOTE: It is critical to update certificate before expiration and to allow a time buffer in case update fails.**

## Mitigation

If the certificate has not yet expired, [renew certificate](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-rollover-cert-cn) before expiration.

If the certificate is self-signed and near expiration and due to health issues the certificate rollover cannot be completed, you may be able to enable the security setting [AcceptExpiredPinnedClusterCertificate](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/How%20to%20recover%20from%20an%20Expired%20Cluster%20Certificate.md) to allow continued access to cluster after expiration.  

## Resolution

Renew certificate.
If certificate is expired, see:

  [Fix Expired Cluster Certificate Automated Script](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20Automated%20Script.md)  
  [Fix Expired Cluster Certificate Manual Steps](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20Manual%20Steps.md)  
  [How to recover from an Expired Cluster Certificate](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/How%20to%20recover%20from%20an%20Expired%20Cluster%20Certificate.md)  

## Reference

https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security-update-certs-azure  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-rollover-cert-cn  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-change-cert-thumbprint-to-cn  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-connect-to-secure-cluster  
