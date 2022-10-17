# How to configure Service Fabric or Applications to use a specific TLS version

Below list some of the options available for configuring TLS and cipher suites. These steps are not specific to Service Fabric and may need to be modified depending on environment and applications being used.

## Option 1 - Machine wide configuration in registry

- This configuration is machine wide restricting OS and applications enforcing TLS 1.2 and secure ciphers. This option uses Custom Script Extension with extension sequencing and Powershell script. [../Scripts/vmss-cse-tls.ps1](../Scripts/vmss-cse-tls.ps1) should be saved to a storage location that is accessible from the Service Fabric nodes during deployment. This script is based off of [Troubleshooting applications that don't support TLS 1.2](https://learn.microsoft.com/en-us/azure/cloud-services/applications-dont-support-tls-1-2) and has been modified to only enable TLS 1.2. Additionally, RC4 and 3DES ciphers have been disabled.

### Modify ARM Template to Add Custom Script Extension

- Add new 'CustomScriptExtension' extension to 'Microsoft.Compute/virtualMachineScaleSets' 'extensions' array. In the following example, dotnet framework 4.8 is installed and node is restarted before installation of the Service Fabric extension. See [custom-script-windows](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows) for additional information.

```json
{
  "name": "CustomScriptExtension",
  "properties": {
    "publisher": "Microsoft.Compute",
    "type": "CustomScriptExtension",
    "typeHandlerVersion": "1.8",
    "autoUpgradeMinorVersion": true,
    "settings": {
      "fileUris": [
        "[parameters('customScriptExtensionFileUri')]"
      ],
      "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
    }
  }
},
```

### Modify ARM Template to add extension sequencing on Service Fabric Extension

- Add 'provisionAfterExtensions' array with 'CustomScriptExtension' in 'properties' section of 'ServiceFabric' extension. See [virtual-machine-scale-sets-extension-sequencing](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing) for additional information.

```json
"provisionAfterExtensions": [
    "CustomScriptExtension"
],
```

### Configuration of TLS and ciphers

- Below are diffs from changes using template.json generated from portal after adding CustomScriptExecution and extension sequencing.
Powershell script [../Scripts/vmss-cse-tls.ps1](../Scripts/vmss-cse-tls.ps1) is example script that configures TLS and ciphers.

#### template.json

```diff
diff --git a/internal/template/template.json b/internal/template/template.json
index f362926..ff080f0 100644
--- a/internal/template/template.json
+++ b/internal/template/template.json
@@ -2,6 +2,18 @@
     "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json",
     "contentVersion": "1.0.0.0",
     "parameters": {
+      "customScriptExtensionFile":{
+        "type": "string",
+        "metadata": {
+          "description": "powershell script file name and arguments for custom script extension to execute"
+        }
+      },
+      "customScriptExtensionFileUri":{
+        "type": "string",
+        "metadata": {
+          "description": "uri of the script file for custom script extension to execute"
+        }
+      },
       "clusterLocation": {
         "type": "string",
           "defaultValue": "westus",
@@ -457,9 +469,27 @@
           "virtualMachineProfile": {
             "extensionProfile": {
               "extensions": [
+                {
+                  "name": "CustomScriptExtension",
+                  "properties": {
+                    "publisher": "Microsoft.Compute",
+                    "type": "CustomScriptExtension",
+                    "typeHandlerVersion": "1.8",
+                    "autoUpgradeMinorVersion": true,
+                    "settings": {
+                      "fileUris": [
+                        "[parameters('customScriptExtensionFileUri')]"
+                      ],
+                    "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
+                    }
+                  }
+                },
                 {
                   "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
                   "properties": {
+                    "provisionAfterExtensions": [
+                      "CustomScriptExtension"
+                  ],
                   "type": "ServiceFabricNode",
                   "autoUpgradeMinorVersion": true,
                   "protectedSettings": {
```

#### template.parameters.json

```diff
diff --git a/internal/template/parameters.json b/internal/template/parameters.json
index 289e771..e598691 100644
--- a/internal/template/parameters.json
+++ b/internal/template/parameters.json
@@ -2,6 +2,12 @@
     "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
+      "customScriptExtensionFile":{
+        "value": "vmss-cse-tls.ps1"
+      },
+      "customScriptExtensionFileUri":{
+        "value": "https://{{ %script storage uri% }}/vmss-cse-tls.ps1"
+      },
       "clusterName": {
         "value": "sf-1nt-5n-cse"
       },
```

## Option 2 - Application level configuration by .exe.config
- Update the .exe app.exe.config, for example FabricUS.exe.config if the process is using .Net Framework 4.6 and above
- DontEnableSchUseStrongCrypto is mapping to "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319\\SchUseStrongCrypto" at per application through the app.config file.
        - [&lt;AppContextSwitchOverrides&gt; element](https://docs.microsoft.com/en-us/dotnet/framework/configure-apps/file-schema/runtime/appcontextswitchoverrides-element)
        - search DontEnableSchUseStrongCrypto

    ```xml
        <?xml version="1.0" encoding="utf-8"?>
            <configuration>
                <runtime>
                    <AppContextSwitchOverrides value="Switch.System.Net.DontEnableSchUseStrongCrypto=false"/>
                <runtime>
            <configuration>
    ```

## Option 3 - Application level configuration by .exe path in registry
- Update registry with path of where .NET .exe is located, like this:
- Valid values are Tls12, Tls11, Tls and Ssl3. Any combination of these values separated by a comma is acceptable.
- Invalid values will be silently treated as if the key is not present: default values will be used instead

    ```
        HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\System.Net.ServicePointManager.SecurityProtocol
        Create REG_SZ string with content
        Name: D:\SvcFab\_App\__FabricSystem_App4294967295\US.Code.Current\FabricUS.exe
        Value: Tls12
    ```

## Verification

- After configuration has been applied and node has been restarted, verify cluster and application functionality. Once cluster and applications have been verified, to verify TLS configuration, there are multiple tools available to check configuration. [Nmap](https://nmap.org) and [IISCrypto](https://www.nartac.com/Products/IISCrypto/) are examples of utilities that can be used.

### Nmap

- To verify configuration with NMAP, [RDP](https://docs.microsoft.com/azure/service-fabric/service-fabric-cluster-remote-connect-to-azure-cluster-node) to node, download [Nmap](https://nmap.org/download), and install.
- From command line, execute command for verification. Example command: nmap --script ssl-enum-ciphers -p 1026 -Pn 10.0.0.4
- Verify configuration is as expected. If there are warnings, review and modify TLS configuration as needed.

#### Nmap example command

```text
PS C:\Program Files (x86)\Nmap> nmap --script ssl-enum-ciphers -p 1026 -Pn 10.0.0.4
Starting Nmap 7.93 ( https://nmap.org ) at 2022-10-15 19:09 Coordinated Universal Time
NSOCK ERROR [0.0720s] ssl_init_helper(): OpenSSL legacy provider failed to load.

Nmap scan report for nt0000000.internal.cloudapp.net (10.0.0.4)
Host is up (0.0010s latency).

PORT     STATE SERVICE
1026/tcp open  LSA-or-nterm
| ssl-enum-ciphers:
|   TLSv1.2:
|     ciphers:
|       TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (secp384r1) - A
|       TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (dh 2048) - A
|       TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (dh 2048) - A
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (secp384r1) - A
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (secp384r1) - A
|       TLS_DHE_RSA_WITH_AES_256_CBC_SHA (dh 2048) - A
|       TLS_DHE_RSA_WITH_AES_128_CBC_SHA (dh 2048) - A
|       TLS_RSA_WITH_AES_256_GCM_SHA384 (rsa 2048) - A
|       TLS_RSA_WITH_AES_128_GCM_SHA256 (rsa 2048) - A
|       TLS_RSA_WITH_AES_256_CBC_SHA256 (rsa 2048) - A
|       TLS_RSA_WITH_AES_128_CBC_SHA256 (rsa 2048) - A
|       TLS_RSA_WITH_AES_256_CBC_SHA (rsa 2048) - A
|       TLS_RSA_WITH_AES_128_CBC_SHA (rsa 2048) - A
|     compressors:
|       NULL
|     cipher preference: server
|_  least strength: A

Nmap done: 1 IP address (1 host up) scanned in 0.87 seconds
PS C:\Program Files (x86)\Nmap>
```

## Linux Clusters

Update the cluster settings in Security section - EnforceLinuxMinTlsVersion and TLS1_2_CipherList as needed

- EnforceLinuxMinTlsVersion	bool, default is FALSE
- Set to true
- Only TLS version 1.2+ is supported. If false, support earlier TLS versions. Applies to Linux only

This setting should enforce TLS1.2 for Service Fabric's Transport and HTTP Gateway. It is not a machine-wide setting. For more information on setting up machine level TLS setting, please contact Ubuntu support - https://ubuntu.com/support

## Reference 

This TSG is primarily discussing SSL/TLS client behavior such as FabricUS.exe. For additional reference, you may check:

- [Restrict the use of certain cryptographic algorithms and protocols in Schannel.dll](https://learn.microsoft.com/en-US/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel)

- [How to Disable SSL 3.0 in Azure Websites, Roles, and Virtual Machines](https://azure.microsoft.com/en-us/blog/how-to-disable-ssl-3-0-in-azure-websites-roles-and-virtual-machines/)

- [Customize Service Fabric cluster settings | Security](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-fabric-settings#security)

If you are **not** looking for schannel driver level security hardening,  but rather want to do it from the .Net Framework level, you can check these MSDN references:

- [Transport Layer Security (TLS) best practices with the .NET Framework](https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls)
- [Mitigation: TLS Protocols](https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/mitigation-tls-protocols)
