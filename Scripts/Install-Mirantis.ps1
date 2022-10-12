# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

<#
.SYNOPSIS
    This script checks if Mirantis needs to be installed by downloading and executing the Mirantis installer, after successful installation the machine will be restarted.
    More information about the Mirantis installer, see: https://docs.mirantis.com/mcr/20.10/install/mcr-windows.html

.NOTES
    v 1.0.2

.PARAMETER dockerVersion
[string] Version of docker to install. Default will be to install latest version.
Format '0.0.0.'

.PARAMETER allowUpgrade
[switch] Allow upgrade of docker. Default is to not upgrade version of docker.

.PARAMETER hypervIsolation
[switch] Install Hyper-V feature / components. Default is to not install Hyper-V feature.
Mirantis install will install container feature.

.PARAMETER installContainerD
[switch] Install containerd. Default is to not install containerd.
containerd is not needed for docker functionality.

.PARAMETER mirantisInstallUrl
[string] Mirantis installation script url. Default is 'https://get.mirantis.com/install.ps1'

.PARAMETER uninstall
[switch] Uninstall docker only. This will not uninstall containerd or Hyper-V feature. 

.PARAMETER norestart
[switch] No restart after installation of docker and container feature. By default, after installation, node is restarted.
Use of -norestart is not supported.

.PARAMETER registerEvent
[bool] If true, will write installation summary information to the Application event log. Default is true.

.PARAMETER registerEventSource
[string] Register event source name used to write installation summary information to the Application event log.. Default name is 'CustomScriptExtension'.

.INPUTS
    None. You cannot pipe objects to Add-Extension.

.OUTPUTS
    Result object from the execution of https://get.mirantis.com/install.ps1.

.EXAMPLE
parameters.json :
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "customScriptExtensionFile": {
      "value": "install-mirantis.ps1"
    },
    "customScriptExtensionFileUri": {
      "value": "https://aka.ms/install-mirantis.ps1"
    },

template json :
"virtualMachineProfile": {
    "extensionProfile": {
        "extensions": [
            {
                "name": "CustomScriptExtension",
                "properties": {
                    "publisher": "Microsoft.Compute",
                    "type": "CustomScriptExtension",
                    "typeHandlerVersion": "1.10",
                    "autoUpgradeMinorVersion": true,
                    "settings": {
                        "fileUris": [
                            "[parameters('customScriptExtensionFileUri')]"
                        ],
                        "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
                    }
                    }
                }
            },
            {
                "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
                "properties": {
                    "provisionAfterExtensions": [
                        "CustomScriptExtension"
                    ],
                    "type": "ServiceFabricNode",

.LINK
    https://github.com/Azure/Service-Fabric-Troubleshooting-Guides
#>

param(
    [string]$dockerVersion = '0.0.0.0', # latest
    [switch]$allowUpgrade,
    [switch]$hypervIsolation,
    [switch]$installContainerD,
    [string]$mirantisInstallUrl = 'https://get.mirantis.com/install.ps1',
    [switch]$uninstall,
    [switch]$noRestart,
    [bool]$registerEvent = $true,
    [string]$registerEventSource = 'CustomScriptExtension'
)

#$PSModuleAutoLoadingPreference = 2
#$ErrorActionPreference = 'continue'
[System.Net.ServicePointManager]::Expect100Continue = $true;
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

$eventLogName = 'Application'
$dockerProcessName = 'dockerd'
$dockerServiceName = 'docker'
$transcriptLog = "$psscriptroot\transcript.log"
$defaultDockerExe = 'C:\Program Files\Docker\dockerd.exe'
$nullVersion = '0.0.0.0'
$versionMap = @{}

function Main() {

    $isAdmin = ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")

    if (!$isAdmin) {s-dockerInstalled
        Write-Error "Restart script as administrator."
        return
    }
    
    Register-Event
    Start-Transcript -Path $transcriptLog
    $error.Clear()

    $installFile = "$psscriptroot\$([System.IO.Path]::GetFileName($mirantisInstallUrl))"
    Write-Host "Installation file:$installFile"

    if (!(Test-Path $installFile)) {
        "Downloading [$url]`nSaving at [$installFile]" 
        Write-Host "$result = [System.Net.WebClient]::New().DownloadFile($mirantisInstallUrl, $installFile)"
        $result = [System.Net.WebClient]::new().DownloadFile($mirantisInstallUrl, $installFile)
        Write-Host "DownloadFile result:$($result | Format-List *)"
    }

    # temp fix
    Add-UseBasicParsing -ScriptFile $installFile

    $version = Set-DockerVersion -dockerVersion $dockerVersion
    $installedVersion = Get-DockerVersion

    if ($hypervIsolation) {
        $hypervInstalled = (Get-WindowsFeature -name hyper-v).Installed
        Write-Host "Windows feature Hyper-V installed:$hypervInstalled"
        
        if (!$uninstall -and !$hypervInstalled) {
            Write-Host "Installing Hyper-V features"
            Install-WindowsFeature -Name hyper-v
            Install-WindowsFeature -Name rsat-hyper-v-tools
            Install-WindowsFeature -Name hyper-v-tools
            Install-WindowsFeature -Name hyper-v-powershell
        }
    }

    if ($uninstall -and (Test-DockerIsInstalled)) {
        Write-Warning "Uninstalling docker. Uninstall:$uninstall"
        $result = Invoke-Script -Script $installFile -Arguments "-Uninstall -verbose 6>&1"
    }
    elseif ($installedVersion -eq $version) {
        Write-Host "Docker $installedVersion already installed and is equal to $version. Skipping install."
        $noRestart = $true
    }
    elseif ($installedVersion -ge $version) {
        Write-Host "Docker $installedVersion already installed and is newer than $version. Skipping install."
        $noRestart = $true
    }
    elseif ($installedVersion -ne $nullVersion -and ($installedVersion -lt $version -and !$allowUpgrade)) {
        Write-Host "Docker $installedVersion already installed and is older than $version. allowupgrade:$allowUpgrade. skipping install."
        $noRestart = $true
    }
    else {
        $engineOnly = $null
        if (!$installContainerD) {
            $engineOnly = "-EngineOnly "
        }
    
        Write-Host "Installing docker."
        $result = Invoke-Script -script $installFile -arguments "-DockerVersion $($versionMap.($version.tostring())) $engineOnly-Verbose 6>&1"

        Write-Host "Install result:$($result | Format-List * | Out-String)"
        Write-Host "Installed docker version:$(Get-DockerVersion)"
        Write-Host "Restarting OS:$(!$noRestart)"
    }

    Stop-Transcript
    Write-Event (Get-Content -raw $transcriptLog)

    if (!$noRestart) {
        Restart-Computer -Force
    }

    return $result
}

# Adding as most Windows Server images have installed PowerShell 5.1 and without this switch Invoke-WebRequest is using Internet Explorer COM API which is causing issues with PowerShell < 6.0.
function Add-UseBasicParsing($scriptFile) {
    $newLine
    $updated = $false
    $scriptLines = [System.IO.File]::ReadAllLines($scriptFile)
    $newScript = [System.Collections.ArrayList]::new()
    Write-Host "Updating $scriptFile to use -UseBasicParsing for Invoke-WebRequest"

    foreach ($line in $scriptLines) {
        $newLine = $line
        if ([System.Text.RegularExpressions.Regex]::IsMatch($line, 'Invoke-WebRequest', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            Write-Host "Found command $line"
            if (![System.Text.RegularExpressions.Regex]::IsMatch($line, '-UseBasicParsing', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                $newLine = [System.Text.RegularExpressions.Regex]::Replace($line, 'Invoke-WebRequest', 'Invoke-WebRequest -UseBasicParsing', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
                Write-Host "Updating command $line to $newLine"
                $updated = $true
            }
        }
        [void]$newScript.Add($newLine)
    }

    if ($updated) {
        $newScriptContent = [string]::Join([System.Environment]::NewLine, $newScript.ToArray())
        $tempFile = "$scriptFile.oem"
        if ((Test-Path $tempFile)) {
            Remove-Item $tempFile -Force
        }
    
        Rename-Item $scriptFile -NewName $tempFile -force
        Write-Host "Saving new script $scriptFile"
        Out-File -InputObject $newScriptContent -FilePath $scriptFile -Force    
    }
}

# Invoke the MCR installer (this will require a reboot)
function Invoke-Script([string]$script, [string] $arguments) {
    Write-Host "Invoke-Expression -Command `"$script $arguments`""
    return Invoke-Expression -Command "$script $arguments"
}

# Get the docker version
function Get-DockerVersion() {
    if (Test-IsDockerRunning) {
        $path = (Get-Process -Name $dockerProcessName).Path
        Write-Host "Docker installed and running: $path"
        $dockerInfo = (docker version)
        $installedVersion = [System.Version][System.Text.RegularExpressions.Regex]::Match($dockerInfo, 'Version:\s+?(\d.+?)\s').Groups[1].Value
    }
    elseif (Test-DockerIsInstalled) {
        $path = Get-WmiObject win32_service | Where-Object { $psitem.Name -like $dockerServiceName } | Select-Object PathName
        Write-Host "Docker exe path:$path"
        $path = [System.Text.RegularExpressions.Regex]::Match($path.PathName, "`"(.+)`"").Groups[1].Value
        Write-Host "Docker exe clean path:$path"
        $installedVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
        Write-Warning "Warning: docker installed but not running: $path"
    }
    else {
        Write-Host "Docker not installed"
        $installedVersion = [System.Version]::new($nullVersion)
    }

    Write-Host "Installed docker defaultPath:$($defaultDockerExe -ieq $path) path:$path version:$installedVersion"
    return $installedVersion
}

# Get the latest docker version
function Get-LatestVersion([string[]] $versions) {
    $latestVersion = [System.Version]::new()
    
    if (!$versions) {
        return [System.Version]::new($nullVersion)
    }

    foreach ($version in $versions) {
        try {
            $currentVersion = [System.Version]::new($version)
            if ($currentVersion -gt $latestVersion) {
                $latestVersion = $currentVersion
            }
        }
        catch {
            $error.Clear()
            continue
        }
    }

    return $latestVersion
}

# Validate if docker is installed
function Test-DockerIsInstalled() {
    $retval = $false

    if ((Get-Service -name $dockerServiceName -ErrorAction SilentlyContinue)) {
        $retval = $true
    }
    
    $error.Clear()
    Write-Host "Docker installed:$retval"
    return $retval
}

# Check if docker is already running
function Test-IsDockerRunning() {
    $retval = $false
    if (Get-Process -Name $dockerProcessName -ErrorAction SilentlyContinue) {
        if (Invoke-Expression 'Docker version') {
            $retval = $true
        }
    }
    
    Write-Host "Docker running:$retval"
    return $retval
}

# Register Windows event source 
function Register-Event() {
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

# Set docker version parameter (script internally)
function Set-DockerVersion($dockerVersion) {
    # install.ps1 using Write-Host to output string data. have to capture with 6>&1
    $currentVersions = Invoke-Script -script $installFile -arguments '-ShowVersions 6>&1'
    Write-Host "Current versions: $currentVersions"
    
    $version = [System.Version]::New($nullVersion)
    $currentdockerVersions = @($currentVersions[0].ToString().TrimStart('docker:').Replace(" ", "").Split(","))
    
    # map string to [version] for 0's
    foreach ($stringVersion in $currentdockerVersions) {
        [void]$versionMap.Add([System.Version]::New($stringVersion).ToString(), $stringVersion)
    }
    
    Write-Host "Version map:`r`n$($versionMap | Out-String)"
    Write-Host "Current docker versions: $currentdockerVersions"
    
    $latestdockerVersion = Get-LatestVersion -versions $currentdockerVersions
    Write-Host "Latest docker version: $latestdockerVersion"
    
    $currentContainerDVersions = @($currentVersions[1].ToString().TrimStart('containerd:').Replace(" ", "").Split(","))
    Write-Host "Current containerd versions: $currentContainerDVersions"

    if ($dockerVersion -ieq 'latest' -or $allowUpgrade) {
        Write-Host "Setting version to latest"
        $version = $latestdockerVersion
    }
    else {
        try {
            $version = [System.Version]::new($dockerVersion)
            Write-Host "Setting version to `$dockerVersion ($dockerVersion)"
        }
        catch {
            $version = [System.Version]::new($nullVersion)
            Write-Warning "Exception setting version to `$dockerVersion ($dockerVersion)`r`n$($error | Out-String)"
        }
    
        if ($version -ieq [System.Version]::new($nullVersion)) {
            $version = $latestdockerVersion
            Write-Host "Setting version to latest docker version $latestdockerVersion"
        }
    }

    Write-Host "Returning target install version: $version"
    return $version
}

# Trace event
function Write-Event($data) {
    Write-Host $data
    $level = 'Information'

    if ($error) {
        $level = 'Error'
        $data = "$data`r`nErrors:`r`n$($error | Out-String)"
    }

    try {
        if ($registerEvent) {
            Write-EventLog -LogName $eventLogName -Source $registerEventSource -Message $data -EventId 1000 -EntryType $level
        }
    }
    catch {
        $error.Clear()
    }
}

Main