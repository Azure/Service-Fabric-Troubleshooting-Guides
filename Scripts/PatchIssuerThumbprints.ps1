# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.  All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# Feedback : anmenard@microsoft.com
# ------------------------------------------------------------

<#

.SYNOPSIS
    Script to expand the set of trusted direct issuers of a service fabric cluster

.DESCRIPTION
    Usage Instructions: Refer to https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20-%20Automated%20Script

.PARAMETER clusterDataRootPath
    service fabric data installation path. default d:\svcfab in azure

.PARAMETER targetIssuerThumbprints
    [required][string] a comma-delimited list of the thumbprints to ADD. E,g, abc...xyz,def...uvw

.PARAMETER nodeIpArray
    [string[]] string array of ip addresses of nodes in cluster

.PARAMETER cacheCredentials
    [switch] enable storing credentials in $global:creds variable.
    to clear, execute: $global:creds=$null

.PARAMETER localOnly
    switch to optionally run script only on local node.
    use when there are connectivity issues between nodes by rdp'ing to each node and running with this switch.

.Parameter hard
    Switch to change the patch style. 
    Default is a soft patch, which is meant to keep the logical node processes, Fabric, FabricHost from closing. 
    Soft patches do not change the fundamental node definition, so a cluster upgrade must be pushed soon after cluster health is restored. 
    Soft patches may need to be run multiple times as nodes regress to their previous definition. 
    A hard patch will change the fundamental node definition, but a cluster upgrade should still be pushed soon after cluster health is restored. 
    Hard patches guarantee that fabric logical node will close, cluster availability loss is all but guaranteed, if not already being experienced. 
    In general hard patches are much less likely to regress on their own.

#>

Param(
    [ValidateNotNullOrEmpty()]
    [string] $clusterDataRootPath = "D:\SvcFab",
    [ValidateNotNullOrEmpty()]
    [string]$targetIssuerThumbprints,
    [ValidateNotNullOrEmpty()]
    [string[]]$nodeIpArray = @("10.0.0.4", "10.0.0.5", "10.0.0.6" ),
    [switch]$cacheCredentials,
    [switch]$localOnly,
    [switch]$hard
)

$error.Clear()
$ErrorActionPreference = 'continue'
$startTime = get-date
$global:failNodes = @()
$global:successNodes = @()
$count = 0
$creds = $null

# remove if on a vm in the vnet, but one which is not part of the cluster
If (!(Test-Path $clusterDataRootPath)) {
    Write-Host $clusterDataRootPath " not found, exiting."
    return
}

$curValue = (get-item wsman:\localhost\Client\TrustedHosts).value

$scriptBlock = { param($clusterDataRootPath, $oldThumbprint, $hard)
    Write-Host "$env:computername : Running on $((Get-WmiObject win32_computersystem).DNSHostName)" -ForegroundColor Green

    function StopServiceFabricServices {
        if ($(Get-Process | ? ProcessName -like "*FabricInstaller*" | measure).Count -gt 0) {
            Write-Warning "$env:computername : Found FabricInstaller running, may cause issues if not stopped, consult manual guide..."
            Write-Host "$env:computername : Pausing (15s)..." -ForegroundColor Green
            Start-Sleep -Seconds 15
        }

        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Running") {
            Stop-Service $bootstrapAgent -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Stopping $bootstrapAgent service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent

            if(!$bootstrapService) {
                break
            }

            if ($bootstrapService.Status -eq "Stopped") {
                Write-Host "$env:computername : $bootstrapAgent now stopped" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $bootstrapAgent current status: $($bootstrapService.Status)" -ForegroundColor Green
            }

        } While ($bootstrapService.Status -ne "Stopped")

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Running") {
            Stop-Service $fabricHost -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Stopping $fabricHost service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost

            if(!$fabricHostService) {
                break
            }

            if ($fabricHostService.Status -eq "Stopped") {
                Write-Host "$env:computername : $fabricHost now stopped" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $fabricHost current status: $($fabricHostService.Status)" -ForegroundColor Green
            }

        } While ($fabricHostService.Status -ne "Stopped")
    }

    function StartServiceFabricServices {
        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Stopped") {
            Start-Service $fabricHost -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Starting $fabricHost service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost

            if(!$fabricHostService) {
                break
            }

            if ($fabricHostService.Status -eq "Running") {
                Write-Host "$env:computername : $fabricHost now running" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $fabricHost current status: $($fabricHostService.Status)" -ForegroundColor Green
            }

        } While ($fabricHostService.Status -ne "Running")


        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Stopped") {
            Start-Service $bootstrapAgent -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Starting $bootstrapAgent service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent

            if(!$bootstrapService) {
                break
            }

            if ($bootstrapService.Status -eq "Running") {
                Write-Host "$env:computername : $bootstrapAgent now running" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $bootstrapAgent current status: $($bootstrapService.Status)" -ForegroundColor Green
            }

        } While ($bootstrapService.Status -ne "Running")
    }

    #config files we need
    #"D:\SvcFab\_sys_0\Fabric\clusterManifest.current.xml"
    #"D:\SvcFab\_sys_0\Fabric\FabricPackage.current.xml"
    #"D:\SvcFab\_sys_0\Fabric\Fabric.Data\InfrastructureManifest.xml"
    #"D:\SvcFab\_sys_0\Fabric\Fabric.Config.1.131523081591497214\Settings.xml"

    $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
    $hostPath = $result.Parent.Parent.Name
    Write-Host "---------------------------------------------------------------------------------------------------------"
    Write-Host "---- Working on ip:" $hostPath
    Write-Host "---------------------------------------------------------------------------------------------------------"

    $manifestFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"
    $packagefile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Package.current.xml"
    $infrastructureManifestFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Data\InfrastructureManifest.xml"

    #to get the settings.xml we need to determine the current version
    #"D:\SvcFab\_sys_0\Fabric\Fabric.Package.current.xml" --> Read to determine verion# <ConfigPackage Name="Fabric.Config" Version="1.131523081591497214" />
    $currentPackageXml = [xml](Get-Content $packageFile)
    $packageName = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Name
    $packageVersion = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Version
    $settingsFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion + "\settings.xml"


    # make a backup folder
    $backupFolder = $clusterDataRootPath + '\Temp\ManifestBackups'
    $backupSettingsFolder = ($backupFolder + "\" +  $packageName + "." + $packageVersion)
    New-Item -ItemType Directory -Force -Path  $backupFolder | out-null
    New-Item -ItemType Directory -Force -Path  $backupSettingsFolder | out-null
    #copy current config to the backup folder
    Copy-Item -Path $settingsFile -Destination ($backupFolder + "\" +  $packageName + "." + $packageVersion) -Force -Verbose
    Copy-Item -Path $packageFile -Destination $backupFolder -Force -Verbose

    if ($hard)
    {
        # if hard patching, backup cluster manifest as well
        Copy-Item -Path $manifestFile -Destination $backupFolder -Force -Verbose

        Write-Host "$env:computername : Stopping services " -ForegroundColor Green
        StopServiceFabricServices
    }

    
    $PatchCertCNEntry = 
    {
        param ($xmlSection,
               $commonName,
               $thumbprints)
        
        if(@($xmlSection.Value).Count -eq 1)
        {
            $xmlSection.Value = $thumbprints
        }
        else
        {
            $xmlSection[@($xmlSection.Name).IndexOf($commonname)].Value = $thumbprints
        }
                
    }

    # settings xml patch
    $settingsXml = [xml](Get-Content $settingsFile)

    $fabricnodesection = $settingsXml.Settings.Section.Get($settingsXml.Settings.Section.Name.IndexOf("FabricNode")).Parameter
    $commonname = $fabricnodesection.Value.get($fabricnodeSection.Name.IndexOf("ClusterX509FindValue"))

    $adminClientSection = $settingsXml.Settings.Section.Get($settingsXml.Settings.Section.Name.IndexOf("Security/AdminClientX509Names")).Parameter
    $clientSection = $settingsXml.Settings.Section.Get($settingsXml.Settings.Section.Name.IndexOf("Security/ClientX509Names")).Parameter
    $clusterSection = $settingsXml.Settings.Section.Get($settingsXml.Settings.Section.Name.IndexOf("Security/ClusterX509Names")).Parameter
    $serverSection = $settingsXml.Settings.Section.Get($settingsXml.Settings.Section.Name.IndexOf("Security/ServerX509Names")).Parameter

    $currentIssuerThumbprints = @($clusterSection.Value).Get(@($clusterSection.Name).IndexOf($commonname))
    Write-Host ("$env:computername : Current issuer configuration is " + $currentIssuerThumbprints + " Target issuer configuration is " + $targetIssuerThumbprints) -ForegroundColor Green


    invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $clusterSection, $commonname, $targetIssuerThumbprints
    invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $serverSection, $commonname, $targetIssuerThumbprints
    invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $adminClientSection, $commonname, $targetIssuerThumbprints
    invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $clientSection, $commonname, $targetIssuerThumbprints

    $settingsXml.Save($settingsFile)
    # end settings xml patch

    if ($hard)
    {

        # manifest xml patch
        Set-ItemProperty -Path $manifestFile -Name IsReadOnly -Value $false
        $manifestXml = [xml](Get-Content $manifestFile)

        $clusterSection = $manifestXml.ClusterManifest.FabricSettings.Section.Get($manifestXml.ClusterManifest.FabricSettings.Section.Name.IndexOf("Security/ClusterX509Names")).Parameter
        $serverSection = $manifestXml.ClusterManifest.FabricSettings.Section.Get($manifestXml.ClusterManifest.FabricSettings.Section.Name.IndexOf("Security/ServerX509Names")).Parameter
        $adminClientSection = $manifestXml.ClusterManifest.FabricSettings.Section.Get($manifestXml.ClusterManifest.FabricSettings.Section.Name.IndexOf("Security/AdminClientX509Names")).Parameter
        $clientSection = $manifestXml.ClusterManifest.FabricSettings.Section.Get($manifestXml.ClusterManifest.FabricSettings.Section.Name.IndexOf("Security/ClientX509Names")).Parameter

        invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $clusterSection, $commonname, $targetIssuerThumbprints
        invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $serverSection, $commonname, $targetIssuerThumbprints
        invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $adminClientSection, $commonname, $targetIssuerThumbprints
        invoke-command -ScriptBlock $PatchCertCNEntry -ArgumentList $clientSection, $commonname, $targetIssuerThumbprints

        $manifestXml.Save($manifestFile)
        # end manifest xml patch

        #update the node configuration
        $logRoot = $clusterDataRootPath + "\Log"
        Write-Host "$env:computername : Updating Node configuration" -ForegroundColor Green
        New-ServiceFabricNodeConfiguration -FabricDataRoot $clusterDataRootPath -FabricLogRoot $logRoot -ClusterManifestPath $manifestFile -InfrastructureManifestPath $infrastructureManifestFile
        Write-Host "$env:computername : Updating Node configuration complete" -ForegroundColor Green

        #restart these services
        Write-Host "$env:computername : Starting services " -ForegroundColor Green
        StartServiceFabricServices
    }
    else
    {
        # we append a benign space to the end of fabric package file, this triggers watchers on this file
        Add-Content -Path $packagefile -Value ' '
    }

    Write-Host "$env:computername : Finished patch" -ForegroundColor Green
}

if ($localOnly) {
    write-host "executing on local node only"
    invoke-command -ScriptBlock $scriptBlock -ArgumentList $clusterDataRootPath, $targetIssuerThumbprints, $hard
    return
}

if (!$global:creds) {
    Write-Host "Enter your RDP Credentials"

    #Get the RDP User Name and Password
    $creds = Get-Credential

    if ($cacheCredentials) {
        $global:creds = $creds
    }
}
else{
    $creds = $global:creds
}

ForEach ($nodeIpAddress in $nodeIpArray) {
    $count++
    #Verifying whether corresponding VM is up and running
    if (Test-Connection -ComputerName $nodeIpAddress -Quiet) {
     
        $activity = "total minutes: $(((get-date) - $startTime).TotalMinutes.tostring("0.0")). connecting to: $nodeIpAddress  ($count of $($nodeIpArray.Count))"
        $status = "success: $($global:successNodes | sort -Unique) fail: $($global:failNodes | sort -Unique)"
        Write-Progress -Activity $activity `
            -Status $status `
            -PercentComplete (($count / $nodeIpArray.Count) * 100)

        write-host "$env:computername : updating trustedhosts list" -foregroundcolor green
        set-item wsman:\localhost\Client\TrustedHosts -value $nodeIpAddress -Force

        Start-Sleep(1)

        $error.clear()
        Invoke-Command -Authentication Negotiate -ComputerName $nodeIpAddress {
            Set-NetFirewallRule -DisplayGroup  'File and Printer Sharing' -Enabled True -PassThru |
            Select-Object DisplayName, Enabled
        } -Credential ($creds)

        if ($error) {
            $global:failNodes += $nodeIpAddress
            continue
        }

        $error.clear()
        Invoke-Command -Authentication Negotiate -Computername $nodeIpAddress -Scriptblock $scriptBlock `
            -ArgumentList $clusterDataRootPath, $targetIssuerThumbprints, $hard
        
        if ($error) {
            $global:failNodes += $nodeIpAddress
        }
        else {
            $global:successNodes += $nodeIpAddress
        }
    }
    else {
        Write-Warning "$env:computername : unable to connect to node: $nodeIpAddress"
        $global:failNodes += $nodeIpAddress
    }
}

write-host "reset trusted hosts to original values" -foregroundcolor green
set-item wsman:\localhost\Client\TrustedHosts -value $curValue -Force
Write-Progress -Completed -Activity "complete"

if ($global:successNodes) {
    $successUnique = $global:successNodes | sort-object -Unique
    write-host "total node success: $(@($successUnique).Count)" -ForegroundColor green
    write-host ($successUnique | fl * | out-string)
}

if ($global:failNodes) {
    $failUnique = $global:failNodes | sort-object -Unique
    write-warning "`r`ntotal node connection errors: $(@($failUnique).Count). review output"   
    write-host ($failUnique | fl * | out-string)
    write-warning "for any failed nodes, rdp to node and run this script with '-localOnly' switch"
}

write-host "finished. total minutes: $(((get-date) - $startTime).TotalMinutes.ToString("0.0"))" -foregroundcolor green