<#
.SYNOPSIS
    example script to install dotnet 8.0 on virtual machine scaleset using custom script extension
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
    invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/install-dotnet-60.ps1" -outFile "$pwd\install-dotnet-60.ps1";
#>

param(
    [string]$dotnetDownloadUrl = 'https://download.visualstudio.microsoft.com/download/pr/d1adccfa-62de-4306-9410-178eafb4eeeb/48e3746867707de33ef01036f6afc2c6/dotnet-sdk-8.0.303-win-x64.exe',
    [version]$version = '8.0.303',
    [bool]$registerEvent = $true,
    [string]$registerEventSource = 'CustomScriptExtension',
    [switch]$restart
)

$PSModuleAutoLoadingPreference = 2
$ErrorActionPreference = 'continue'
[net.servicePointManager]::Expect100Continue = $true;
[net.servicePointManager]::SecurityProtocol = [net.SecurityProtocolType]::Tls12;

function main() {
    $installLog = "$psscriptroot\install.log"
    $transcriptLog = "$psscriptroot\transcript.log"
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if(!$isAdmin){
        Write-Warning "restart script as administrator"
        return
    }
    
    register-event

    $installedVersion = get-dotnetVersion
    if ($installedVersion -ge $version) {
        write-event "dotnet $installedVersion already installed"
        return
    }

    Start-Transcript -Path $transcriptLog

    $installFile = "$psscriptroot\$([io.path]::GetFileName($dotnetDownloadUrl))"
    write-host "installation file:$installFile"

    if (!(test-path $installFile)) {
        "Downloading [$url]`nSaving at [$installFile]" 
        write-host "$result = [net.webclient]::new().DownloadFile($dotnetDownloadUrl, $installFile)"
        $result = [net.webclient]::new().DownloadFile($dotnetDownloadUrl, $installFile)
        write-host "downloadFile result:$($result | Format-List *)"
    }

    $argumentList = "/q /log $installLog"

    if (!$restart) {
        $argumentList += " /norestart"
    }

    write-host "
        `$result = Invoke-Command -ScriptBlock { 
            Start-Process -FilePath $installFile -ArgumentList $argumentList -Wait -PassThru 
        }
    "
    
    $result = Invoke-Command -ScriptBlock { 
        Start-Process -FilePath $installFile -ArgumentList $argumentList -Wait -PassThru 
    }

    write-host "install result:$($result | Format-List * | out-string)"
    Write-Host "installed dotnet version final:$(get-dotnetVersion)"
    write-host "install log:`r`n$(Get-Content -raw $installLog)"
    write-host "restarting OS:$restart"

    Stop-Transcript
    write-event (get-content -raw $transcriptLog)

    if($restart) {
        Restart-Computer -Force
    }

    return $result
}

function register-event() {
    if ($registerEvent) {
        $error.clear()
        New-EventLog -LogName $eventLogName -Source $registerEventSource -ErrorAction silentlycontinue
        if($error -and ($error -inotmatch 'source is already registered')) {
            $registerEvent = $false
        }
        else {
            $error.clear()
        }
    }
}

function write-event($data) {
    write-host $data

    try {
        if ($registerEvent) {
            Write-EventLog -LogName 'Application' -Source $registerEventSource -Message $data -EventId 1000
        }
    }
    catch {
        $error.Clear()
    }
}

function get-dotnetVersion() {
    $dotnetExe = 'C:\Program Files\dotnet\dotnet.exe'
    if ((test-path $dotnetExe)) {
        $dotnetInfo = (. $dotnetExe --info)
        $installedVersion = [version][regex]::match($dotnetInfo, 'Version:\s+?(\d.+?)\s').groups[1].value
    }
    else {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
        $installedVersion = [version]((Get-ItemProperty -Path $registryPath -Name Version).Version)
    }
    
    write-host "installed dotnet version:$installedVersion"
    return $installedVersion
}

main
