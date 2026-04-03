<#
.SYNOPSIS
    Example script to connect to service fabric managed cluster using common name certificate

    This script requires powershell modules 'serviceFabric' that is installed on development machines  with service fabric sdk and service fabric nodes.
    This script requires Azure 'Az' modules.

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

.EXAMPLE
    .\sfmc-connect.ps1 -clusterEndpoint mycluster.eastus.cloudapp.azure.com -commonName *.mycluster.com

.EXAMPLE
    .\sfmc-connect.ps1 -clusterEndpoint mycluster.eastus.cloudapp.azure.com -thumbprint ABCD... -domainNameLabelScope

.LINK
    invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/sfmc-connect.ps1" -outFile "$pwd\sfmc-connect.ps1";

#>
param(
    [Parameter(ParameterSetName = 'thumbprint', Mandatory = $true)]
    [Parameter(ParameterSetName = 'commonName', Mandatory = $true)]
    $clusterEndpoint = "cluster.location.cloudapp.azure.com",
    
    [Parameter(ParameterSetName = 'commonName', Mandatory = $true)]
    $commonName,
    
    [Parameter(ParameterSetName = 'thumbprint', Mandatory = $true)]
    $thumbprint,

    [Parameter(ParameterSetName = 'thumbprint')]
    [Parameter(ParameterSetName = 'commonName')]
    [ValidateSet('LocalMachine', 'CurrentUser')]
    $storeLocation = "CurrentUser",

    [Parameter(ParameterSetName = 'thumbprint')]
    [Parameter(ParameterSetName = 'commonName')]
    $storeName = 'My',
    
    [Parameter(ParameterSetName = 'thumbprint')]
    [Parameter(ParameterSetName = 'commonName')]
    $clusterendpointPort = 19000,
    
    [Parameter(ParameterSetName = 'thumbprint')]
    [Parameter(ParameterSetName = 'commonName')]
    [switch]$domainNameLabelScope
)

function main() {
    $serverCertThumbprint = ''
    $certs = @()

    if ($commonName) {
        $findType = 'FindBySubjectName'
        $findValue = $commonName
        $certs = @(get-clientCert -storeLocation $storeLocation -storeName $storeName -commonName $commonName)
    }
    elseif ($thumbprint) {
        $findType = 'FindByThumbprint'
        $findValue = $thumbprint
        $certs = @(get-clientCert -storeLocation $storeLocation -storeName $storeName -thumbprint $thumbprint)
    }
    else {
        write-error 'provide thumbprint or commonname'
        return
    }

    if($certs.Count -gt 1) {
        write-warning "found multiple certificates: $($certs | convertto-json)"
    }
    elseif($certs.Count -lt 1 -or ($certs.Count -eq 1 -and !$certs[0])) {
        write-warning "unable to find certificate."
    }
    else {
        write-host "found certificate: $($certs[0] | convertto-json)" -ForegroundColor Green
    }

    if (!(Test-NetConnection $clusterEndpoint -Port $clusterendpointPort)) {
        write-error "unable to ping $clusterEndpoint port $clusterEndpointPort"
        return
    }

    if (!(get-command Connect-ServiceFabricCluster | out-null)) {
        import-module servicefabric
        if (!(get-command Connect-ServiceFabricCluster)) {
            write-error "unable to import servicefabric powershell module. try executing script from a working node."
            return
        }
    }

    if (!(get-command get-azresource)) {
        if (!(import-module az)) {
            write-error "unable to import azure 'az' module. to install 'az': install-module az"
            return
        }
    }

    $global:cluster = Get-azServiceFabricManagedCluster | Where-Object Fqdn -imatch $clusterEndpoint.replace(":$clusterEndpoint", "")
    if (!$cluster) {
        write-error "unable to find cluster $clusterEndpoint"
        return
    }

    $cluster | ConvertTo-Json -Depth 99
    $clusterId = $cluster.Id

    write-host "(Get-AzResource -ResourceId $clusterId).Properties.clusterCertificateThumbprints" -ForegroundColor Green
    $serverCertThumbprint = (Get-AzResource -ResourceId $clusterId).Properties.clusterCertificateThumbprints

    if (!$serverCertThumbprint) {
        write-error "unable to get server thumbprint"
        return
    }
    else {
        write-host "using server thumbprint:$serverCertThumbprint" -ForegroundColor Cyan
    }

    # Extract FQDN for ServerCommonName if using domainNameLabelScope
    $clusterFqdn = $clusterEndpoint -replace ':\d+$', ''
    
    if ($domainNameLabelScope) {
        write-host "Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint`:$clusterendpointPort ``
            -ServerCommonName $clusterFqdn ``
            -StoreLocation $storeLocation ``
            -StoreName $storeName ``
            -X509Credential ``
            -FindType $findType ``
            -FindValue $findValue ``
            -Verbose" -ForegroundColor Green

        Connect-ServiceFabricCluster -ConnectionEndpoint "$clusterEndpoint`:$clusterendpointPort" `
            -ServerCommonName $clusterFqdn `
            -StoreLocation $storeLocation `
            -StoreName $storeName `
            -X509Credential `
            -FindType $findType `
            -FindValue $findValue `
            -verbose
    }
    else {
        write-host "Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint`:$clusterendpointPort ``
            -ServerCertThumbprint $serverCertThumbprint ``
            -StoreLocation $storeLocation ``
            -StoreName $storeName ``
            -X509Credential ``
            -FindType $findType ``
            -FindValue $findValue ``
            -Verbose" -ForegroundColor Green

        Connect-ServiceFabricCluster -ConnectionEndpoint "$clusterEndpoint`:$clusterendpointPort" `
            -ServerCertThumbprint $serverCertThumbprint `
            -StoreLocation $storeLocation `
            -StoreName $storeName `
            -X509Credential `
            -FindType $findType `
            -FindValue $findValue `
            -verbose
    }
}

function get-clientCert($storeLocation, $storeName, $thumbprint = $null, $commonName = $null) {
    if ($thumbprint) {
        $pscerts = @(Get-ChildItem -Path Cert:\$storeLocation\$storeName -Recurse | Where-Object Thumbprint -eq $thumbprint)
    }
    elseif ($commonName) {
        $pscerts = @(Get-ChildItem -Path Cert:\$storeLocation\$storeName -Recurse | Where-Object { $psitem.SubjectName.Name -imatch [regex]::Escape($commonName) })
    }
    else {
        return $null
    }
    
    [collections.generic.list[System.Security.Cryptography.X509Certificates.X509Certificate]] $certCol = [collections.generic.list[System.Security.Cryptography.X509Certificates.X509Certificate]]::new()

    foreach ($cert in $pscerts) {
        [void]$certCol.Add([System.Security.Cryptography.X509Certificates.X509Certificate]::new($cert))
    }

    write-host "certcol: $($certCol | convertto-json)"

    if (!$certCol) {
        write-error "certificate with thumbprint:$thumbprint commonName:$commonName not found in certstore:$storeLocation\$storeName"
        return $null
    }

    Write-host "certificate with thumbprint:$thumbprint commonName:$commonName found in certstore:$storeLocation\$storeName" -ForegroundColor Green
    return $certCol.ToArray()
}

main