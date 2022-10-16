# How to ACL application certificate private key using ApplicationManifest.xml

Applications using a certificate for secure communication over https need to have the Access Control List (ACL) configured with Full permissions for the user context being used for the application process. There is currently no process or extension including Key vault virtual machine ([KVVM](https://learn.microsoft.com/azure/virtual-machines/extensionskey-vault-windows)) that performs this ACL automatically for application certificates. Service Fabric will only automatically ACL the cluster certificate. If a certificate is deployed to a Service Fabric cluster, and the application cannot access the private key (returns null), it is possible the private key is not ACL'd correctly. By default, Service Fabric (fabrichost.exe) starts applications using the 'NetworkService' account, so the private key has to be ACL'd to allow this account to access it.

The following example configures the Principle and sets the ACL using SecurityAccessPolicies using ApplicationManifest.xml. Two different certs are updated, an EndpointCertificate and a simple SecretsCertificate. These settings could also be placed in the ServiceManifest.xml. See [Manage encrypted secrets in Service Fabric applications](https://docs.microsoft.com/azure/service-fabric/service-fabric-application-secret-management) for additional information.

## ApplicationManifest.xml Configuration

In '&lt;Principals&gt;&lt;Users&gt;' section, add '&lt;User&gt;' element for the user account executing application. By default the 'AccountType' is 'NetworkService'.  
In '&lt;Policies&gt;&lt;SecurityAccessPolicies&gt;' section, add '&lt;SecurityAccessPolicy&gt;' for each certificate needing to be ACL'd.  
In '&lt;Certificates&gt;' section, add a &lt;Certificate&gt; element for each certificate.

## Example ApplicationManifest.xml with SecurityAccessPolicies

```xml
<ApplicationManifest>
 …
 …
 …
 …
<Principals>
	<Users>
		<User Name="Service1" AccountType="NetworkService" />
	</Users>
</Principals>
<Policies>
	<SecurityAccessPolicies>
		<SecurityAccessPolicy ResourceRef="EncryptionCert" PrincipalRef="Service1" ResourceType="Certificate" />
		<SecurityAccessPolicy ResourceRef="WebAdminCert" PrincipalRef="Service1" ResourceType="Certificate" />
	</SecurityAccessPolicies>
</Policies>
<Certificates>
	<SecretsCertificate X509FindValue="[EncryptionThumbprint]" Name="EncryptionCert" />
	<EndpointCertificate X509FindValue="[ApplicationClientThumbprint]" Name="WebAdminCert" />
</Certificates>
</ApplicationManifest>
```

## Troubleshooting

- To verify which user context is being used, [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to any node running application and view the process in Task Manager 'Details' tab.

  ![](../media/task-manager-user-context.png)

- To verify ACL permissions on a certificate, [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to any node running application and view certificate in Microsoft Management Console (mmc.exe). Open certlm.msc (mmc local machine certificates shortcut), right click on certificate being used, and select 'Manage private keys...'. The 'User name' for the process in 'Task Manager' needs to have 'Full control' ACL permissions on certificate private key being used.

  ![](../media/certlm-manage-private-keys.png)

  ![](../media/certlm-certificate-acl.png)

- If unable to determing issue, [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to any node running application, open 'Event Viewer' (eventvwr.exe) 'Application' and 'Microsoft-Service Fabric/Admin' logs and review for errors.

  ![](../media/eventvwr-microsoft-service-fabric.png)

## Reference

- [Service Fabric application and service manifests](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-manifests)
- [SecurityAccessPolicies element](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#securityaccesspolicies-element)
- [SecurityAccessPolicy element](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#securityaccesspolicy-element)
- [Principals element](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#principals-element)

- [Assign a security access policy for HTTP and HTTPS endpoints](https://learn.microsoft.com/azure/service-fabric/service-fabric-assign-policy-to-endpoint)
- [Service Fabric application and service security](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-security)
- [Manage certificates in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificate-management)
- [Grant NETWORK SERVICE access to the certificate's private key](https://learn.microsoft.com/azure/service-fabric/service-fabric-tutorial-dotnet-app-enable-https-endpoint#grant-network-service-access-to-the-certificates-private-key)
