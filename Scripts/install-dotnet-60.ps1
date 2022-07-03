<#
.SYNOPSIS
    example script to install dotnet on virtual machine scaleset using custom script extension
    use custom script extension in ARM template
    save file to url that vmss nodes have access to during provisioning
    
.NOTES
    v 1.0
    use: https://dotnet.microsoft.com/download to get download links

.LINK
    [net.servicePointManager]::Expect100Continue = $true;[net.servicePointManager]::SecurityProtocol = [net.securityProtocolType]::Tls12;
    invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/install-dotnet-60.ps1" -outFile "$pwd\install-dotnet-60.ps1";

#>
param(
    [string]$dotnetDownloadUrl = 'https://download.visualstudio.microsoft.com/download/pr/7989338b-8ae9-4a5d-8425-020148016812/c26361fde7f706279265a505b4d1d93a/dotnet-runtime-6.0.6-win-x64.exe',
    [version]$version = '6.0.6',
    [switch]$norestart,
    [bool]$registerEvent = $true,
    [string]$registerEventSource = 'CustomScriptExtensionPS'
)

$PSModuleAutoLoadingPreference = 2
$ErrorActionPreference = 'continue'
[net.servicePointManager]::Expect100Continue = $true;
[net.servicePointManager]::SecurityProtocol = [net.SecurityProtocolType]::Tls12;

function main() {

    if ($registerEvent) {
        if (!(get-eventlog -LogName 'Application' -Source $registerEventSource)) {
            New-EventLog -LogName 'Application' -Source $registerEventSource
        }
    }
    
    $installedVersion = get-dotnetVersion
    if ($installedVersion -ge $version) {
        write-event "dotnet $installedVersion already installed"
        return
    }

    $transcriptLog = "$psscriptroot/transcript.log"
    Start-Transcript -Path $transcriptLog

    $installFile = "$psscriptroot\$([io.path]::GetFileName($dotnetDownloadUrl))"
    write-host "installation file:$installFile"

    if (!(test-path $installFile)) {
        "Downloading [$url]`nSaving at [$installFile]" 
        write-host "$result = Invoke-WebRequest -Uri $dotnetDownloadUrl -OutFile $installFile"
        $result = Invoke-WebRequest -Uri $dotnetDownloadUrl -OutFile $installFile
        write-host "invoke-webrequest result:$($result | Format-List *)"
    }

    $installLog = '$psscriptroot\install.log'
    $argumentList = "/q /log $installLog"

    if (!$norestart) {
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
    Stop-Transcript
    write-event (get-content -raw $transcriptLog)
    return $result
}

function write-event($data) {
    write-host $data

    if ($registerEvent) {
        Write-EventLog -LogName 'Application' -Source $registerEventSource -Message $data -EventId 1000
    }
}

function get-dotnetVersion() {
    $dotnetExe = 'C:\Program Files\dotnet\dotnet.exe'
    if ((test-path $dotnetExe)) {
        $dotnetInfo = (. $dotnetExe --info)
        $installedVersion = [version][regex]::match($dotnetInfo, 'Version: (.+?)\s').groups[1].value
    }
    else {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
        $installedVersion = [version]((Get-ItemProperty -Path $registryPath -Name Version).Version)
    }
    
    write-host "installed dotnet version:$installedVersion"
    return $installedVersion
}

main
