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
    [bool]$norestart = $true,
    [bool]$registerEvent = $true,
    [string]$registerEventSource = 'CustomScriptExtensionPS'
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
        write-host "$result = Invoke-WebRequest -Uri $dotnetDownloadUrl -OutFile $installFile"
        $result = Invoke-WebRequest -Uri $dotnetDownloadUrl -OutFile $installFile
        write-host "invoke-webrequest result:$($result | Format-List *)"
    }

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

function register-event() {
    try {
        if ($registerEvent) {
            if (!(get-eventlog -LogName 'Application' -Source $registerEventSource -ErrorAction silentlycontinue)) {
                New-EventLog -LogName 'Application' -Source $registerEventSource
            }
        }
    }
    catch {
        write-host "exception:$($error | out-string)"
        $error.clear()
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
