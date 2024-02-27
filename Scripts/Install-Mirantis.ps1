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
    v 1.0.4 adding support for docker ce using 
        https://github.com/microsoft/Windows-Containers/tree/Main/helpful_tools/Install-DockerCE 
        https://docs.docker.com/desktop/install/windows-install/
        https://learn.microsoft.com/en-us/azure/virtual-machines/acu

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

[cmdletbinding()]
param(
    [string]$dockerVersion = '0.0.0.0', # latest
    [string]$containerDVersion = '0.0.0.0', # latest
    [switch]$allowUpgrade,
    [switch]$hypervIsolation,
    [switch]$installContainerD,
    [string]$mirantisInstallUrl = 'https://get.mirantis.com/install.ps1',
    [switch]$dockerCe,
    [switch]$uninstall,
    [switch]$noRestart,
    [switch]$noExceptionOnError,
    [bool]$registerEvent = $true,
    [string]$registerEventSource = 'CustomScriptExtension',
    [switch]$whatIf
)

#$PSModuleAutoLoadingPreference = 2
#$ErrorActionPreference = 'continue'
[Net.ServicePointManager]::Expect100Continue = $true;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

$eventLogName = 'Application'
$dockerProcessName = 'dockerd'
$dockerServiceName = 'docker'
$transcriptLog = "$psscriptroot\transcript.log"
$defaultDockerExe = 'C:\Program Files\Docker\dockerd.exe'
$nullVersion = '0.0.0.0'
$versionMap = @{}
$mirantisRepo = 'https://repos.mirantis.com'
$dockerCeRepo = 'https://download.docker.com'
$dockerPackageAbsolutePath = 'win/static/stable/x86_64'
$dockerOfflineFile = "$psscriptroot/Docker.zip"
$containerDOfflineFile = "$psscriptroot/Containerd.zip"
$maxEventMessageSize = 16384  #32766 - 1000

$global:currentDockerVersions = @{}
$global:currentContainerDVersions = @{}
$global:downloadUrl = $mirantisRepo
$global:restart = !$noRestart
$global:result = $true

function Main() {

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if (!$isAdmin) {
        Write-Error "Restart script as administrator."
        return $false
    }
    
    Register-Event
    Start-Transcript -Path $transcriptLog
    $error.Clear()

    $installFile = "$psscriptroot\$([IO.Path]::GetFileName($mirantisInstallUrl))"
    Write-Host "Installation file:$installFile"

    if (!(Test-Path $installFile)) {
        Download-File -url $mirantisInstallUrl -outputFile $installFile
    }

    # temp fix
    Add-UseBasicParsing -ScriptFile $installFile

    $dockerVersion = Set-DockerVersion -dockerVersion $dockerVersion
    $installedVersion = Get-InstalledDockerVersion

    # install windows-features
    Install-Feature -name 'containers'

    if ($hypervIsolation) {
        Install-Feature -Name 'hyper-v'
        Install-Feature -Name 'rsat-hyper-v-tools'
        Install-Feature -Name 'hyper-v-tools'
        Install-Feature -Name 'hyper-v-powershell'
    }

    if ($uninstall -and (Test-DockerIsInstalled)) {
        Write-Warning "Uninstalling docker. Uninstall:$uninstall"
        Invoke-Script -Script $installFile -Arguments "-Uninstall -verbose 6>&1"
    }
    elseif ($installedVersion -eq $dockerVersion) {
        Write-Host "Docker $installedVersion already installed and is equal to $dockerVersion. Skipping install."
        $global:restart = $false
    }
    elseif ($installedVersion -ge $dockerVersion) {
        Write-Host "Docker $installedVersion already installed and is newer than $dockerVersion. Skipping install."
        $global:restart = $false
    }
    elseif ($installedVersion -ne $nullVersion -and ($installedVersion -lt $dockerVersion -and !$allowUpgrade)) {
        Write-Host "Docker $installedVersion already installed and is older than $dockerVersion. allowupgrade:$allowUpgrade. skipping install."
        $global:restart = $false
    }
    else {
        $error.Clear()
        $dockerInstallArgs = @{}
        [void]$dockerInstallArgs.Add('dockerVersion', $dockerVersion.ToString())
        [void]$dockerInstallArgs.Add('offline', $null)
        [void]$dockerInstallArgs.Add('offlinePackagesPath', $psscriptroot)
        [void]$dockerInstallArgs.Add('verbose', $null)

        if ($global:restart) {
            [void]$dockerInstallArgs.Add('noServiceStarts', $null)
        }

        if ($dockerCe) {
            $global:downloadUrl = $dockerCeRepo
        }

        if (!$installContainerD) {
            [void]$dockerInstallArgs.Add('engineOnly', $null)
        }
        else {
            # download containerd outside mirantis script
            $containerDVersion = Set-ContainerDVersion -containerDVersion $containerDVersion
            $containerDDownloadFile = $global:currentContainerDVersions.Item($containerDVersion)
            
            # containerd only in mirantis repo
            Download-File -url "$mirantisRepo/$dockerPackageAbsolutePath/$containerDDownloadFile" -outputFile $containerDOfflineFile
            [void]$dockerInstallArgs.Add('containerDVersion', $containerDVersion.ToString())
        }

        # download docker outside mirantis script
        $dockerDownloadFile = $global:currentDockerVersions.Item($dockerVersion)
        Download-File -url "$global:downloadUrl/$dockerPackageAbsolutePath/$dockerDownloadFile" -outputFile $dockerOfflineFile

        # docker script will always emit errors checking for files even when successful
        Write-Host "Installing docker."
        $scriptResult = Invoke-Script -script $installFile `
            -argumentsTable $dockerInstallArgs `
            -checkError $false
        
        $error.Clear()
        $finalVersion = Get-InstalledDockerVersion
        if ($finalVersion -eq $nullVersion) {
            Write-Host "setting `$global:result to false: finalversion:$finalVersion nullversion:$nullversion"
            $global:result = $false
        }

        Write-Host "Install result:$($scriptResult | Format-List * | Out-String)"
        Write-Host "Global result:$global:result"
        Write-Host "Installed docker version:$finalVersion"
        Write-HOst "docker.exe output: $(docker | out-string)"
        Write-Host "Restarting OS:$global:restart"
    }

    Stop-Transcript

    $transcript = Get-Content -raw $transcriptLog
    Write-Event -data $transcript


    if (!$whatIf -and $global:result -and $global:restart) {
        # prevent sf extension from trying to install before restart
        Start-Process powershell '-c', {
            $outvar = $null;
            $mutex = [threading.mutex]::new($true, 'Global\ServiceFabricExtensionHandler.A6C37D68-0BDA-4C46-B038-E76418AFC690', [ref]$outvar);
            write-host $mutex;
            write-host $outvar;
            read-host;
        }

        # return immediately after this call
        Restart-Computer -Force
    }

    if (!$noExceptionOnError -and !$global:result) {
        throw [Exception]::new("Exception $($MyInvocation.ScriptName)`n$($transcript)")
    }
    return $global:result
}

# Adding as most Windows Server images have installed PowerShell 5.1 and without this switch Invoke-WebRequest is using Internet Explorer COM API which is causing issues with PowerShell < 6.0.
function Add-UseBasicParsing($scriptFile) {
    $newLine
    $updated = $false
    $scriptLines = [io.file]::ReadAllLines($scriptFile)
    $newScript = [collections.arrayList]::new()
    Write-Host "Updating $scriptFile to use -UseBasicParsing for Invoke-WebRequest"

    foreach ($line in $scriptLines) {
        $newLine = $line
        if ([regex]::IsMatch($line, 'Invoke-WebRequest', [text.regularExpressions.regexOptions]::IgnoreCase)) {
            Write-Host "Found command $line"
            if (![regex]::IsMatch($line, '-UseBasicParsing', [text.regularExpressions.regexOptions]::IgnoreCase)) {
                $newLine = [regex]::Replace($line, 'Invoke-WebRequest', 'Invoke-WebRequest -UseBasicParsing', [text.regularExpressions.regexOptions]::IgnoreCase)
                Write-Host "Updating command $line to $newLine"
                $updated = $true
            }
        }
        [void]$newScript.Add($newLine)
    }

    if ($updated) {
        $newScriptContent = [string]::Join([Environment]::NewLine, $newScript.ToArray())
        $tempFile = "$scriptFile.oem"
        if ((Test-Path $tempFile)) {
            Remove-Item $tempFile -Force
        }

        Rename-Item $scriptFile -NewName $tempFile -force
        Write-Host "Saving new script $scriptFile"
        Out-File -InputObject $newScriptContent -FilePath $scriptFile -Force    
    }
}

function Download-File($url, $outputFile) {
    Write-Host "$result = [net.webClient]::new().downloadFile($url, $outputFile)"
    [net.webClient]::new().downloadFile($url, $outputFile)
    Write-Host "DownloadFile result:$($result | Format-List *)"

    if ($error -or !(Test-Path $outputFile)) {
        Write-Error "failure downloading file:$($error | out-string)"
        $global:result = $false
    }
    elseif($whatIf) {
        [io.file]::delete($outputFile)
    }
}

# Get the docker version
function Get-InstalledDockerVersion() {
    $installedVersion = [version]::new($nullVersion)

    if (Test-IsDockerRunning) {
        $path = (Get-Process -Name $dockerProcessName).Path
        Write-Host "Docker installed and running: $path"
        $dockerInfo = (docker version)
        $installedVersion = [version][regex]::Match($dockerInfo, 'Version:\s+?(\d.+?)\s').Groups[1].Value
    }
    elseif (Test-DockerIsInstalled) {
        $path = Get-WmiObject win32_service | Where-Object { $psitem.Name -like $dockerServiceName } | Select-Object PathName
        Write-Host "Docker exe path:$path"
        $path = [regex]::Match($path.PathName, "`"(.+)`"").Groups[1].Value
        Write-Host "Docker exe clean path:$path"
        $installedVersion = [version]::new([diagnostics.fileVersionInfo]::GetVersionInfo($path).FileVersion)
        Write-Warning "Warning: docker installed but not running: $path"
    }
    else {
        Write-Host "Docker not installed"
    }

    Write-Host "Installed docker defaultPath:$($defaultDockerExe -ieq $path) path:$path version:$installedVersion"
    return $installedVersion
}

# Get Available Versions
function Get-AvailableVersions() {
    # install.ps1 using Write-Host to output string data. have to capture with 6>&1
    # for docker ce and mirantis compat, query versions outside install.ps1

    if ($global:currentDockerVersions.Count -lt 1 -or $global:currentContainerDVersions.Count -lt 1) {
        $result = Invoke-WebRequest -Uri "$global:downloadUrl/$dockerPackageAbsolutePath" -UseBasicParsing

        $filePattern = '(?<file>(?<filetype>docker|containerd)-(?<major>\d+?)\.(?<minor>\d+?)\.(?<build>\d+?)\.zip)'
        $linkMatches = [regex]::matches($result.Links.href, $filePattern, [text.regularExpressions.regexOptions]::IgnoreCase)

        foreach ($match in $linkMatches) {
            $major = $match.groups['major'].value
            $minor = $match.groups['minor'].value
            $build = $match.groups['build'].value
            $version = [version]::new($major, $minor, $build)

            $file = $match.groups['file'].value
            $filetype = $match.groups['filetype'].value
        
            if ($filetype -ieq 'docker') {
                [void]$global:currentDockerVersions.Add($version, $file)
            }
            else {
                [void]$global:currentContainerDVersions.Add($version, $file)
            }
        }
    }
}

# Get the latest docker version
function Get-LatestVersion([string[]] $versions) {
    $latestVersion = [version]::new()
    
    if (!$versions) {
        return [version]::new($nullVersion)
    }

    foreach ($version in $versions) {
        try {
            $currentVersion = [version]::new($version)
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

# Install Windows-Feature if not installed
function Install-Feature([string]$name) {
    $feautureResult = $null
    $isInstalled = (Get-WindowsFeature -name $name).Installed
    Write-Host "Windows feature '$name' installed:$isInstalled"

    if (!$isInstalled) {
        Write-Host "Installing windows feature '$name'"
        $feautureResult = Install-WindowsFeature -Name $name
        if (!$feautureResult.Success) {
            Write-Error "error installing feature:$($error | out-string)"
            $global:result = $false
        }
        else {
            if (!$noRestart) {
                $global:restart = $global:restart -or $feautureResult.RestartNeeded -ieq 'yes'
                Write-Host "`$global:restart set to $global:restart"
            }
        }
    }

    return $feautureResult
}

# Invoke the MCR installer (this will require a reboot)
function Invoke-Script([string]$script, [string] $arguments = $null, [hashtable] $argumentsTable = @{}, [bool]$checkError = $true) {
    $scriptResult = $null
    if($argumentsTable.Count -gt 0) {
        foreach($arg in $argumentsTable.GetEnumerator()) {
            $argValue = $null
            if($arg.Value) {
                $argValue = " '$($arg.Value)'"
            }
            $arguments += " -$($arg.Key)$argValue"
        }
    }

    Write-Host "Invoke-Expression -Command `"$script $arguments`""

    if (!$whatIf) {
        $scriptResult = Invoke-Expression -Command "$script $arguments"
    }

    return $scriptResult
}

# Set version parameter
function Set-Version($version, $currentVersions) {
    $setVersion = $version
    Write-Host "Current versions: $($currentVersions | out-string)"

    $latestVersion = Get-LatestVersion -versions $currentVersions.Keys
    Write-Host "Latest version: $latestVersion"

    if ($version -eq $nullVersion -or $version -ieq 'latest' -or $allowUpgrade) {
        Write-Host "Setting version to latest"
        $setVersion = $latestVersion
    }
    else {
        try {
            $setVersion = [version]::new($version)
            Write-Host "Setting version to $setVersion"
        }
        catch {
            $setVersion = [version]::new($nullVersion)
            Write-Warning "Exception setting version to $version`r`n$($error | Out-String)"
        }
    
        if ($setVersion -ieq [version]::new($nullVersion)) {
            $setVersion = $latestdockerVersion
            Write-Host "Setting version to latest version $latestVersion"
        }
    }

    Write-Host "Returning target install version: $setVersion"
    return $setVersion
}

# Set containerd version parameter
function Set-ContainerDVersion($containerDVersion) {
    Get-AvailableVersions
    Write-Host "Requesting containerd target install version: $containerDVersion"
    $version = Set-Version -version $containerDVersion -currentVersions $global:currentContainerDVersions
    Write-Host "Returning containerd target install version: $version"
    return $version
}

# Set docker version parameter
function Set-DockerVersion($dockerVersion) {
    Get-AvailableVersions
    Write-Host "Requesting docker target install version: $dockerVersion"
    $version = Set-Version -version $dockerVersion -currentVersions $global:currentDockerVersions
    Write-Host "Returning docker target install version: $version"
    return $version
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
        if ($error -and ($error -inotmatch 'source is already registered')) {
            $registerEvent = $false
        }
        else {
            $error.clear()
        }
    }
}

# Trace event
function Write-Event($data, $level = 'Information') {
    Write-Host $data

    if (!$global:result -or $error -or $level -ieq 'Error') {
        $level = 'Error'
        $data = "$data`r`nErrors:`r`n$($error | Out-String)"
        Write-Error $data
        $error.Clear()
    }

    try {
        if ($registerEvent) {
            $index = 0
            $counter = 1
            $totalEvents = [int]($data.Length / $maxEventMessageSize)

            while ($index -lt $data.Length) {
                $header = "$counter of $totalEvents`n"
                $counter++
                $dataSize = [math]::Min($data.Length - $index, $maxEventMessageSize)
                Write-Verbose "`$data.Substring($index, $dataSize)"
                $dataChunk = $header
                $dataChunk += $data.Substring($index, $dataSize)
                $index += $dataSize

                Write-EventLog -LogName $eventLogName `
                    -Source $registerEventSource `
                    -Message $dataChunk `
                    -EventId 1000 `
                    -EntryType $level

            }
        }
    }
    catch {
        Write-Host "exception writing event to event log:$($error | out-string)"
        $error.Clear()
    }
}

Main