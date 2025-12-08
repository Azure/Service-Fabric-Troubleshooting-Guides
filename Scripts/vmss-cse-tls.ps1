<#
.SYNOPSIS
    powershell script for enabling TLS 1.2 and TLS 1.3 (on Windows Server 2022+)
    based on https://learn.microsoft.com/en-us/azure/cloud-services/applications-dont-support-tls-1-2
    modified to enable TLS 1.2 and TLS 1.3

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
    You can use the -SetCipherOrder (or -sco) option to also set the TLS cipher
    suite order. Change the cipherorder variable below to the order you want to set on the
    server. Setting this requires a reboot to take effect.
    
    Use the -NoRestart option to suppress automatic reboot after applying registry changes.
    This is useful for testing, scheduled maintenance windows, or when using orchestration
    tools to manage reboots. Note: A reboot is required for TLS configuration changes to
    take effect.
    
    v1.1

    Windows Registry Editor Version 5.00

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL]
    "EventLogging"=dword:00000001

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128]
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128]
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128]
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64/128]
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168]
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\CipherSuites]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client]
    "DisabledByDefault"=dword:00000001
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server]
    "DisabledByDefault"=dword:00000001
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client]
    "Enabled"=dword:00000000
    "DisabledByDefault"=dword:00000001

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server]
    "Enabled"=dword:00000000
    "DisabledByDefault"=dword:00000001

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client]
    "DisabledByDefault"=dword:00000001
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server]
    "DisabledByDefault"=dword:00000001
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client]
    "DisabledByDefault"=dword:00000001
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server]
    "DisabledByDefault"=dword:00000001
    "Enabled"=dword:00000000

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client]
    "DisabledByDefault"=dword:00000000
    "Enabled"=dword:00000001

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server]
    "DisabledByDefault"=dword:00000000
    "Enabled"=dword:00000001

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3]

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client]
    "DisabledByDefault"=dword:00000000
    "Enabled"=dword:00000001

    [HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server]
    "DisabledByDefault"=dword:00000000
    "Enabled"=dword:00000001

.LINK
[net.servicePointManager]::Expect100Continue = $true;[net.servicePointManager]::SecurityProtocol = [net.SecurityProtocolType]::Tls12;
invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/vmss-cse-tls.p1" -outFile "$pwd\vmss-cse-tls.p1";
./vmss-cse-tls.ps1

#>

[cmdletbinding()]
param (
    [parameter(Mandatory = $false)]
    [alias("sco")]
    [switch]$SetCipherOrder,
    [bool]$registerEvent = $true,
    [string]$registerEventSource = 'CustomScriptExtension',
    [switch]$whatif,
    [parameter(Mandatory = $false)]
    [switch]$NoRestart
)

$eventLogName = 'Application'
$sslPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002"

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

function Set-RegistrySetting {
    param (
        $key,
        $value,
        $valuedata,
        $valuetype,
        $restart
    )

    # Check for existence of registry key, and create if it does not exist  
    foreach ($keySegment in ($key.split('\'))) {
        if ($path) {
            $parentDirectory = [io.path]::GetDirectoryName($path)
            $parentKeyName = [io.path]::getFileName($path)
        }

        $path = "$path\$keySegment".TrimStart('\')
        write-verbose "checking $path"
        
        if (!(Test-Path -Path $path)) {
            write-host "creating $path" -ForegroundColor Green
            $keyObject = Get-Item $parentDirectory
            $subkey = $keyObject.OpenSubKey($parentKeyName, $true)
            
            if (!$whatif) {
                $subkey.CreateSubKey($keySegment)
            }
        }
    }

    # Get data of registry value, or null if it does not exist
    $val = (Get-ItemProperty -Path $key -Name $value -ErrorAction SilentlyContinue).$value

    if ($error -and ($error -imatch 'does not exist at path')) {
        $error.clear()
    }

    if ($null -eq $val) {
        # Value does not exist - create and set to desired value
        write-host "New-ItemProperty -Path $key -Name $value -Value $valuedata -PropertyType $valuetype" -ForegroundColor Green
        if (!$whatif) {
            New-ItemProperty -Path $key -Name $value -Value $valuedata -PropertyType $valuetype | Out-Null
        }
        $restart = $True
        Write-Host "Configuring $key...."

    }
    else {

        # Value does exist - if not equal to desired value, change it
        if ($val -ne $valuedata) {
            write-host "Set-ItemProperty -Path $key -Name $value -Value $valuedata" -ForegroundColor Green

            if (!$whatif) {
                Set-ItemProperty -Path $key -Name $value -Value $valuedata
            }
            $restart = $True
            Write-Host "Configuring $key..."
        }
    }

    $restart

}

function Set-Windows10PlusCurveOrder {
    param ( $reboot)
    $desiredOrder = "NistP384;NistP256".Split(";")
    if ([Environment]::OSVersion.Version.Major -ge 10) {
        if (!(Test-Path -Path $sslPolicyKey)) {
            New-Item $sslPolicyKey | Out-Null
            $reboot = $True
        }

        $val = (Get-Item -Path $sslPolicyKey -ErrorAction SilentlyContinue).GetValue("EccCurves", $null)

        if ( $null -eq $val) {
            New-ItemProperty -Path $sslPolicyKey -Name EccCurves -Value $desiredOrder -PropertyType MultiString | Out-Null
            $reboot = $True

        }
        else {

            if ([System.String]::Join(';', $val) -ne [System.String]::Join(';', $desiredOrder)) {
                Write-Host "The original curve order ", `n, $val, `n, "needs to be updated to ", $desiredOrder
                Set-ItemProperty -Path $sslPolicyKey -Name EccCurves -Value $desiredOrder
                $reboot = $True
            }
        }
    }

    $reboot
}

function Write-Event($data, $retry = $true) {
    write-host $data
    try {
        if ($registerEvent) {
            $level = 'Information'

            if ($error -or ($data -imatch "fail|exception|error")) {
                $level = 'Error'
                $data = "$data`r`nerrors:`r`n$($error | out-string)"
            }
            elseif ($error -or ($data -imatch "warn")) {
                $level = 'Warning'
            }

            Write-EventLog -LogName $eventLogName -Source $registerEventSource -Message $data -EventId 1000 -EntryType $level
        }
    }
    catch {
        $error.Clear()
    }
}

Register-Event

if ([Environment]::OSVersion.Version.Major -lt 10) {
    # This is for Windows before 10
    Write-Host "Configuring Windows before 10..."
    $cipherorder = "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256_P256,"
    $cipherorder += "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384_P384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256_P256,"
    $cipherorder += "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384_P256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P256,"
    $cipherorder += "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA_P256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA_P256,"
    $cipherorder += "TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,"
    $cipherorder += "TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,"
    $cipherorder += "TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA"

}
else {

    # this is for windows 10 or above
    Write-Host "Configuring Windows 10+..."
    $cipherorder = "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,"
    $cipherorder += "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,"
    $cipherorder += "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,"
    $cipherorder += "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,"
    $cipherorder += "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,"
    $cipherorder += "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,"
    $cipherorder += "TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,"
    $cipherorder += "TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,"
    $cipherorder += "TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA"
}

# if any settings are changed, this will change to $True and the server will reboot
$reboot = $False
$protocolsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

# Ensure SSL 2.0 disabled for client/server
$reboot = Set-RegistrySetting "$protocolsKey\SSL 2.0\Client" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\SSL 2.0\Client" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\SSL 2.0\Server" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\SSL 2.0\Server" Enabled 0 DWord $reboot

# Ensure SSL 3.0 disabled for client/server
$reboot = Set-RegistrySetting "$protocolsKey\SSL 3.0\Client" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\SSL 3.0\Client" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\SSL 3.0\Server" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\SSL 3.0\Server" Enabled 0 DWord $reboot

# Ensure TLS 1.0 disabled for client/server
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.0\Client" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.0\Client" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.0\Server" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.0\Server" Enabled 0 DWord $reboot

# Ensure TLS 1.1 disabled for client/server
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.1\Client" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.1\Client" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.1\Server" DisabledByDefault 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.1\Server" Enabled 0 DWord $reboot

# Ensure TLS 1.2 enabled for client/server
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.2\Client" DisabledByDefault 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.2\Client" Enabled 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.2\Server" DisabledByDefault 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.2\Server" Enabled 1 DWord $reboot

# Ensure TLS 1.3 enabled for client/server (Windows Server 2022+)
# Note: TLS 1.3 is enabled by default on Windows Server 2022, but these settings ensure explicit configuration
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.3\Client" DisabledByDefault 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.3\Client" Enabled 1 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.3\Server" DisabledByDefault 0 DWord $reboot
$reboot = Set-RegistrySetting "$protocolsKey\TLS 1.3\Server" Enabled 1 DWord $reboot

$ciphersKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers'

# Disable RC4 ciphers
$reboot = Set-RegistrySetting "$ciphersKey\RC4 128/128" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$ciphersKey\RC4 64/128" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$ciphersKey\RC4 56/128" Enabled 0 DWord $reboot
$reboot = Set-RegistrySetting "$ciphersKey\RC4 40/128" Enabled 0 DWord $reboot

# Disable 3DES cipher
$reboot = Set-RegistrySetting "$ciphersKey\Triple DES 168" Enabled 0 DWord $reboot

# Enable legacy .net strong crypto
$reboot = Set-RegistrySetting "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" SchUseStrongCrypto 1 DWord $reboot
$reboot = Set-RegistrySetting "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" SchUseStrongCrypto 1 DWord $reboot

if ($SetCipherOrder) {
    if (!(Test-Path -Path $sslPolicyKey)) {
        New-Item $sslPolicyKey | Out-Null
        $reboot = $True
    }

    $val = (Get-Item -Path $sslPolicyKey -ErrorAction SilentlyContinue).GetValue("functions", $null)

    if ($val -ne $cipherorder) {
        Write-Host "The original cipher suite order needs to be updated", `n, $val
        Set-ItemProperty -Path $sslPolicyKey -Name functions -Value $cipherorder
        $reboot = $True
    }
}

$reboot = Set-Windows10PlusCurveOrder $reboot
$currentReg = [string]::Join("`r`n", (reg query 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -s))

if ($reboot -and !$NoRestart) {
    # Randomize the reboot timing since it could be run in a large cluster.
    $tick = [System.Int32]([System.DateTime]::Now.Ticks % [System.Int32]::MaxValue)
    $rand = [System.Random]::new($tick)
    $sec = $rand.Next(30, 600)

    Write-Event -data "current registry:
        $currentReg
        
        Successfully updated crypto settings
        Warning:Rebooting after $sec second(s)...
        shutdown.exe /r /t $sec /c ""Crypto settings changed"" /f /d p:2:4
        "
    if (!$whatif) {
        shutdown.exe /r /t $sec /c "Crypto settings changed" /f /d p:2:4
    }
}
elseif ($reboot -and $NoRestart) {
    Write-Event -data "current registry:
        $currentReg
    
        Successfully updated crypto settings
        Warning: Restart required for changes to take effect. Use -NoRestart to suppress automatic reboot.
        "
}
else {
    Write-Event -data "current registry:
        $currentReg
    
        Crypto settings already set. not restarting.
        "
}
