# Installing Mirantis Container Runtime for Azure Service Fabric service

## Abstract 

This document is to guide through the process of doing a post-deployment to install Mirantis Container Runtime in the specific scenario of hosting Service Fabric Runtime on Azure Virtual Machine Scale Sets safely.

## Use VM Scale Set Custom Script Extensions to install Mirantis

Each node type in a Service Fabric cluster is backed by a virtual machine scale set. This enables you to add [virtual machine scale set extensions](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/overview) to your Service Fabric cluster node types. Extensions are small applications that provide post-deployment configuration and automation on Azure VMs. The Azure platform hosts many extensions covering VM configuration, monitoring, security, and utility applications. Publishers take an application, wrap it into an extension, and simplify the installation. All you need to do is provide mandatory parameters.

For testing purposes you can add a virtual machine scale set extension to an Azure Service Fabric cluster node type using the [Add-AzVmssExtension](https://docs.microsoft.com/powershell/module/az.compute/add-azvmssextension) PowerShell command.

The recommended way to add a virtual machine scale set extension on an Azure Service Fabric cluster node type is your Azure Resource Manager template.

The PowerShell script is prepared to check if Mirantis needs to be installed by downloading and executing the Mirantis installer, after successful installation the machine will be restarted.

Please use a copy of [Install-Mirantis.ps1](https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/Install-Mirantis.ps1) to install Mirantis Container Runtime on your Azure Service Fabric cluster. If your Service Fabric project is hyper-v isolated container based, add script switch '-hypervIsolation' to the 'commandToExecute' variable.

Example:

```json
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File .\\Install-Mirantis.ps1 -hypervIsolation"
```

> [!NOTE] It is highly recommended to save scripts somewhere in your own storage to be protected to changes from external sources. In this way your production environment will not face untested scenarios. Please use a copy of the scripts provided as any change should be tested first before going into production.

```json
"virtualMachineProfile": {
    "extensionProfile": {
        "extensions": [
            {
                "name": "CustomScriptExtension-Mirantis",
                "properties": {
                    "publisher": "Microsoft.Compute",
                    "type": "CustomScriptExtension",
                    "typeHandlerVersion": "1.10",
                    "autoUpgradeMinorVersion": true,
                    "settings": {
                        "fileUris": [
                            "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/Install-Mirantis.ps1"
                        ],
                        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File .\\Install-Mirantis.ps1"
                    }
                    }
                }
            },
```

The Custom Script VM Extension to install Mirantis must run before Service Fabric VM Extension. Mirantis must be installed before Service Fabric can run, therefore it is mandatory to use extension sequencing. 

> [!WARNING] As soon as the Service Fabric node has joined the cluster ring, it is dangerous to make uncontrolled VM restarts. Please make sure to always use extension sequencing to finish the installation of Mirantis first.

```json
            {
                "name": "ServiceFabricNodeTypeA",
                "properties": {
                    "provisionAfterExtensions": [
                        "CustomScriptExtension-Mirantis"
                    ],
                    "type": "ServiceFabricNode",
```

## Troubleshooting

If using [Install-Mirantis.ps1](https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/Install-Mirantis.ps1) to install Mirantis with default of 'registerEvent' set to true, an event be logged to the 'Application' event log. The script will write the powershell transcript of the installation using 'Source' of 'CustomScriptExtension' by default.

There are also status and log files in multiple locations on the local c: drive of the virtual machine.

### File locations

#### **Extension status**

The x.status file(s) are a json files containing the status of the Custom Script Extension and execution of install-mirantis script output.

- C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\\<version\>\Status\\<version\>.status
    - Example: C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.15\Status\1.status

#### **File downloads**

File downloads will have the install-mirantis script file if download was successful. In addition, if installation started, the powershell transcript.log will be written to this location.

- C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\\<version\>\Downloads\\<version\>

    ```text
    C:\PACKAGES\PLUGINS\MICROSOFT.COMPUTE.CUSTOMSCRIPTEXTENSION\1.10.15\DOWNLOADS
    └───1
            install-mirantis.ps1
            install.ps1
            install.ps1.oem
            transcript.log
    ```

#### **Extension log archive**

Contains output similar to above locations but also contains history of previous executions with additional extension logging.

- C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\\<version\>

    ```text
    C:\WINDOWSAZURE\LOGS\PLUGINS\MICROSOFT.COMPUTE.CUSTOMSCRIPTEXTENSION
    └───1.10.15
        CommandExecution.log
        CommandExecution_20230416135036514.log
        CommandExecution_20230416135328172.log
        CommandExecution_20230416135720159.log
        CommandExecution_20230416135905790.log
        CustomScriptHandler.log
    ```

## Documentation

- [Custom Script Extension for Windows](https://docs.microsoft.com/azure/virtual-machines/extensions/custom-script-windows)
- [Sequence extension provisioning in virtual machine scale sets](https://docs.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing)
- [Tutorial: Install applications in virtual machine scale sets with Azure PowerShell](https://docs.microsoft.com/azure/virtual-machine-scale-sets/tutorial-install-apps-powershell)
- [Get started: Prep Windows for containers](https://docs.microsoft.com/virtualization/windowscontainers/quick-start/set-up-environment?tabs=dockerce)
