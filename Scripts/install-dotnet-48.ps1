<#
.SYNOPSIS
    example script to install dotnet 4.8 on virtual machine scaleset using custom script extension
    use custom script extension in ARM template
    save file to url that vmss nodes have access to during provisioning

Microsoft Privacy Statement: https://privacy.microsoft.com/en-US/privacystatement

MIT License

Copyright (c) Microsoft Corporation. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE

    
.NOTES
    v 1.0
    use: https://dotnet.microsoft.com/download to get download links

.LINK
    [net.servicePointManager]::Expect100Continue = $true;[net.servicePointManager]::SecurityProtocol = [net.securityProtocolType]::Tls12;
    invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/install-dotnet-48.ps1" -outFile "$pwd\install-dotnet-48.ps1";
#>

param(
    [switch]$restart
)

$url = "https://go.microsoft.com/fwlink/?linkid=2088631" 
$registryPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
$installedVersion = [version]((Get-ItemProperty -Path $registryPath -Name Version).Version)
$installedVersion

if($installedVersion -ge [version]("4.8")) {
    write-host "dotnet 4.8 already installed"
    return
}

$path = "$psscriptroot\ndp48-x86-x64-allos-enu.exe" 
$path

if(!(test-path $path)) {
    "Downloading [$url]`nSaving at [$path]" 
    (new-object net.webClient).DownloadFile($url, $path) 
}

$argumentList = "/q /log $psscriptroot\install.log"
if (!$restart) { $argumentList += " /norestart" }

Invoke-Command -ScriptBlock { Start-Process -FilePath $path -ArgumentList $argumentList -Wait -PassThru } 
Write-Host (Get-ItemProperty -Path $registryPath -Name Version).Version