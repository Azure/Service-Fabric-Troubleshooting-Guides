# How to ACL application certificate private key using ApplicationManifest.xml

Applications using a certificate for secure communication over https need to have the Access Control List (ACL) configured with Full permissions for the user context being used for the application process. There is currently no process or extension including Key vault virtual machine ([KVVM](https://learn.microsoft.com/azure/virtual-machines/extensionskey-vault-windows)) that performs this ACL automatically for application certificates as Service Fabric will only automatically ACL the cluster certificate. If a certificate is deployed to a Service Fabric cluster, and the application cannot access the private key (returns null), it is possible the private key is not ACL'd correctly. By default, Service Fabric (fabrichost.exe) starts applications using the 'Network Service' account, so the private key has to be ACL'd to allow this account to access it. Using configuration below, Service Fabric will ACL the certificate private key automatically.

The following example configures the Principal and sets the private key ACL using SecurityAccessPolicies in ApplicationManifest.xml. Two different certs are updated, an EndpointCertificate and a simple SecretsCertificate. See [Assign a security access policy for HTTP and HTTPS endpoints](https://learn.microsoft.com/azure/service-fabric/service-fabric-assign-policy-to-endpoint) and [Manage encrypted secrets in Service Fabric applications](https://docs.microsoft.com/azure/service-fabric/service-fabric-application-secret-management)
 for additional information.

## ApplicationManifest.xml Configuration

- **'&lt;Principals&gt;&lt;Users&gt;'** section - Add **'&lt;User&gt;'** element for the user account executing application. By default the 'AccountType' is 'NetworkService' for user 'Network Service'. See [AccountType](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#accounttype) for list of all account types.
- **'&lt;Policies&gt;&lt;SecurityAccessPolicies&gt;'** section - Add **'&lt;SecurityAccessPolicy&gt;'** for each certificate needing to be ACL'd.  
- **'&lt;Certificates&gt;'** section - Add **'&lt;EndpointCertificate&gt;'** element for the endpoint certificate and if using an encryption certificate, add the **'&lt;SecretsCertificate&gt;'**.

## Example ApplicationManifest.xml with SecurityAccessPolicies

```xml
<ApplicationManifest>
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
- [SecurityAccessPolicy element](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#securityaccesspolicy-element)
- [User element](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-model-schema-elements#user-element)
- [Run a service startup script as a local user or system account](https://learn.microsoft.com/azure/service-fabric/service-fabric-run-script-at-service-startup)

- [Service Fabric application and service security](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-and-service-security)
- [Manage certificates in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificate-management)
- [Grant NETWORK SERVICE access to the certificate's private key](https://learn.microsoft.com/azure/service-fabric/service-fabric-tutorial-dotnet-app-enable-https-endpoint#grant-network-service-access-to-the-certificates-private-key)
- [Specify resources in a service manifest](https://learn.microsoft.com/azure/service-fabric/service-fabric-service-manifest-resources)
