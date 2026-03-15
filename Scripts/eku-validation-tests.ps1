#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive EKU validation tests for SF client certificate authentication.
    Tests every row of the compatibility matrix in the EKU document.

.DESCRIPTION
    Runs all client compatibility matrix tests from:
    Security/certificate-client-authentication-eku-removal-impact.md
    
    Includes SF REST passive testing (read-only API validation).

.PARAMETER ClusterFqdn
    The FQDN of the SF cluster (e.g., sfjagilber1nt5so.centralus.cloudapp.azure.com)

.PARAMETER ServerOnlyThumbprint
    Thumbprint of the certificate with ONLY Server Authentication EKU

.PARAMETER BothEkuThumbprint
    Thumbprint of the certificate with BOTH Server and Client Authentication EKUs

.PARAMETER OutputDir
    Directory for test results/evidence. Default: script directory\results

.EXAMPLE
    .\eku-validation-tests.ps1 `
        -ClusterFqdn "sfjagilber1nt5so.centralus.cloudapp.azure.com" `
        -ServerOnlyThumbprint "65E7734F5E95DD1AE965EE219EBB2C6B85F04BD0" `
        -BothEkuThumbprint "D71B8B2D1078B9AAAC50660145CC4C3822A53B55"
#>

param(
    [Parameter(Mandatory)]
    [string]$ClusterFqdn,

    [Parameter(Mandatory)]
    [string]$ServerOnlyThumbprint,

    [Parameter(Mandatory)]
    [string]$BothEkuThumbprint,

    [string]$OutputDir = (Join-Path $PSScriptRoot "results")
)

$ErrorActionPreference = 'Continue'
$baseUrl = "https://${ClusterFqdn}:19080"
$tcpEndpoint = "${ClusterFqdn}:19000"
$apiPath = "/`$/GetClusterHealth?api-version=9.1&timeout=10"
$nodesPath = "/Nodes?api-version=9.1&timeout=10"
$appsPath = "/Applications?api-version=9.1&timeout=10"
$manifestPath = "/`$/GetClusterManifest?api-version=9.1&timeout=10"

# Create output dir
if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultFile = Join-Path $OutputDir "eku-test-results-$timestamp.txt"

function Write-TestResult {
    param([string]$TestId, [string]$Description, [string]$Expected, [string]$Actual, [string]$Details = "")
    $passed = ($Expected -eq $Actual)
    $status = if ($passed) { "MATCH" } else { "MISMATCH" }
    $color = if ($passed) { "Green" } else { "Red" }
    
    $line = "[$status] $TestId | $Description | Expected: $Expected | Actual: $Actual"
    if ($Details) { $line += " | $Details" }
    
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $resultFile -Value $line
    
    return [PSCustomObject]@{
        TestId = $TestId
        Description = $Description
        Expected = $Expected
        Actual = $Actual
        Match = $passed
        Details = $Details
    }
}

# Header
$header = @"
============================================================
EKU Validation Test Results
============================================================
Cluster:              $ClusterFqdn
Server-only cert:     $ServerOnlyThumbprint
Both-EKU cert:        $BothEkuThumbprint
Timestamp:            $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)
PowerShell Version:   $($PSVersionTable.PSVersion)
OS:                   $($PSVersionTable.OS)
============================================================

"@
Write-Host $header -ForegroundColor Cyan
Set-Content -Path $resultFile -Value $header

$results = @()

# ============================================================
# PHASE 2a: TCP Tests (Connect-ServiceFabricCluster)
# ============================================================
Write-Host "`n--- T1: Connect-ServiceFabricCluster (TCP 19000) ---" -ForegroundColor Yellow

try {
    # Connect-ServiceFabricCluster uses TCP (System.Fabric.FabricClient) 
    # which does NOT go through SChannel, so it should work with server-only cert
    $sfCert = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint" -ErrorAction Stop
    Connect-ServiceFabricCluster -ConnectionEndpoint $tcpEndpoint `
        -X509Credential `
        -ServerCertThumbprint $ServerOnlyThumbprint `
        -FindType FindByThumbprint `
        -FindValue $ServerOnlyThumbprint `
        -StoreLocation CurrentUser `
        -StoreName My `
        -ErrorAction Stop | Out-Null
    
    $clusterHealth = Get-ServiceFabricClusterHealth -ErrorAction Stop
    $actual = "PASS"
    $details = "ClusterHealth: $($clusterHealth.AggregatedHealthState)"
    Disconnect-ServiceFabricCluster -ErrorAction SilentlyContinue | Out-Null
} catch {
    $actual = "FAIL"
    $details = $_.Exception.Message.Substring(0, [Math]::Min(200, $_.Exception.Message.Length))
}
$results += Write-TestResult -TestId "T1" -Description "Connect-ServiceFabricCluster TCP (server-only cert)" -Expected "PASS" -Actual $actual -Details $details

# ============================================================
# PHASE 2b: HTTP Tests - Expected FAIL with server-only cert
# ============================================================
Write-Host "`n--- T7: PowerShell 5.1 Invoke-WebRequest (server-only cert) ---" -ForegroundColor Yellow

# PS 5.1 tests need to run in powershell.exe (Windows PowerShell)
$ps51TestScript = @"
`$ErrorActionPreference = 'Continue'
`$cert = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
# Accept all server certs for self-signed SF
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}

try {
    `$response = Invoke-WebRequest -Uri "$baseUrl$apiPath" -Certificate `$cert -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Write-Output "PASS|`$(`$response.StatusCode)|`$(`$response.Content.Substring(0, [Math]::Min(100, `$response.Content.Length)))"
} catch {
    Write-Output "FAIL|0|`$(`$_.Exception.Message.Substring(0, [Math]::Min(200, `$_.Exception.Message.Length)))"
}
"@

try {
    $ps51Result = powershell.exe -NoProfile -Command $ps51TestScript 2>&1
    $parts = ($ps51Result | Out-String).Trim().Split('|', 3)
    $actual = $parts[0]
    $details = "Status: $($parts[1]) | $($parts[2])"
} catch {
    $actual = "FAIL"
    $details = "PS 5.1 execution error: $($_.Exception.Message)"
}
$results += Write-TestResult -TestId "T7" -Description "PS 5.1 Invoke-WebRequest (server-only cert)" -Expected "FAIL" -Actual $actual -Details $details

Write-Host "`n--- T8: PowerShell 5.1 Invoke-RestMethod (server-only cert) ---" -ForegroundColor Yellow

$ps51IRMScript = @"
`$ErrorActionPreference = 'Continue'
`$cert = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}

try {
    `$response = Invoke-RestMethod -Uri "$baseUrl$apiPath" -Certificate `$cert -TimeoutSec 15 -ErrorAction Stop
    Write-Output "PASS|200|`$(`$response | ConvertTo-Json -Compress -Depth 1 | Select-Object -First 1)"
} catch {
    Write-Output "FAIL|0|`$(`$_.Exception.Message.Substring(0, [Math]::Min(200, `$_.Exception.Message.Length)))"
}
"@

try {
    $ps51IRMResult = powershell.exe -NoProfile -Command $ps51IRMScript 2>&1
    $parts = ($ps51IRMResult | Out-String).Trim().Split('|', 3)
    $actual = $parts[0]
    $details = "Status: $($parts[1]) | $($parts[2])"
} catch {
    $actual = "FAIL"
    $details = "PS 5.1 IRM execution error: $($_.Exception.Message)"
}
$results += Write-TestResult -TestId "T8" -Description "PS 5.1 Invoke-RestMethod (server-only cert)" -Expected "FAIL" -Actual $actual -Details $details

Write-Host "`n--- T9: PowerShell 7 Invoke-RestMethod -Certificate (server-only cert) ---" -ForegroundColor Yellow

try {
    $cert = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint"
    $response = Invoke-RestMethod -Uri "$baseUrl$apiPath" `
        -Certificate $cert `
        -SkipCertificateCheck `
        -TimeoutSec 15 `
        -ErrorAction Stop
    $actual = "PASS"
    $details = ($response | ConvertTo-Json -Compress -Depth 1).Substring(0, [Math]::Min(200, ($response | ConvertTo-Json -Compress -Depth 1).Length))
} catch {
    $actual = "FAIL"
    $details = $_.Exception.Message.Substring(0, [Math]::Min(200, $_.Exception.Message.Length))
}
$results += Write-TestResult -TestId "T9" -Description "PS 7 Invoke-RestMethod -Certificate (server-only cert)" -Expected "FAIL" -Actual $actual -Details $details

# ============================================================
# PHASE 2c: HTTP Tests - Expected PASS (bypass SChannel)
# ============================================================
Write-Host "`n--- T4: curl with server-only cert ---" -ForegroundColor Yellow

try {
    # curl on Windows uses SChannel by default, but with --cert-type P12 it can bypass
    # Actually, curl uses the cert store directly - we need to export the cert first
    $certPath = Join-Path $OutputDir "server-only-cert.pfx"
    $certObj = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint"
    
    # Use curl with --cert pointing to the thumbprint in the cert store
    # Windows curl supports cert store: --cert "CurrentUser\My\<thumbprint>"
    $curlResult = & curl.exe -s -k --cert-type P12 `
        -E "CurrentUser\My\$ServerOnlyThumbprint" `
        "$baseUrl$apiPath" 2>&1
    
    $curlOutput = $curlResult | Out-String
    if ($curlOutput -match '"AggregatedHealthState"' -or $curlOutput -match 'HealthState') {
        $actual = "PASS"
        $details = $curlOutput.Substring(0, [Math]::Min(200, $curlOutput.Length))
    } else {
        # Try alternative curl invocation
        $curlResult2 = & curl.exe -s -k "$baseUrl$apiPath" --cert "Cert:\CurrentUser\My\$ServerOnlyThumbprint" 2>&1
        $curlOutput2 = $curlResult2 | Out-String
        if ($curlOutput2 -match '"AggregatedHealthState"') {
            $actual = "PASS"
            $details = $curlOutput2.Substring(0, [Math]::Min(200, $curlOutput2.Length))
        } else {
            $actual = "FAIL"
            $details = "curl output: $($curlOutput.Substring(0, [Math]::Min(200, $curlOutput.Length)))"
        }
    }
} catch {
    $actual = "FAIL"
    $details = "curl error: $($_.Exception.Message)"
}
$results += Write-TestResult -TestId "T4" -Description "curl with server-only cert" -Expected "PASS" -Actual $actual -Details $details

# ============================================================
# PHASE 2d: SF REST Passive Tests
# ============================================================
Write-Host "`n--- SF REST Passive Testing ---" -ForegroundColor Yellow

# T12: Get-SFClusterHealth with server-only cert (PS HTTP module uses SChannel → FAIL)
Write-Host "`n--- T12: Get-SFClusterHealth via SF HTTP Module (server-only cert) ---" -ForegroundColor Yellow
try {
    Import-Module Microsoft.ServiceFabric.Powershell.Http -ErrorAction Stop
    Connect-SFCluster -ConnectionEndpoint $baseUrl `
        -X509Credential `
        -ServerCertThumbprint $ServerOnlyThumbprint `
        -FindType FindByThumbprint `
        -FindValue $ServerOnlyThumbprint `
        -StoreLocation CurrentUser `
        -StoreName My `
        -ErrorAction Stop
    
    $sfHealth = Get-SFClusterHealth -ErrorAction Stop
    $actual = "PASS"
    $details = "HealthState: $($sfHealth.AggregatedHealthState)"
} catch {
    $actual = "FAIL"
    $details = $_.Exception.Message.Substring(0, [Math]::Min(200, $_.Exception.Message.Length))
}
$results += Write-TestResult -TestId "T12" -Description "Get-SFClusterHealth via SF HTTP Module (server-only cert)" -Expected "FAIL" -Actual $actual -Details $details

# T13: Get-SFClusterHealth with both-EKU cert (should PASS)
Write-Host "`n--- T13: Get-SFClusterHealth via SF HTTP Module (both-EKU cert) ---" -ForegroundColor Yellow
try {
    Connect-SFCluster -ConnectionEndpoint $baseUrl `
        -X509Credential `
        -ServerCertThumbprint $ServerOnlyThumbprint `
        -FindType FindByThumbprint `
        -FindValue $BothEkuThumbprint `
        -StoreLocation CurrentUser `
        -StoreName My `
        -ErrorAction Stop
    
    $sfHealth = Get-SFClusterHealth -ErrorAction Stop
    $actual = "PASS"
    $details = "HealthState: $($sfHealth.AggregatedHealthState)"
} catch {
    $actual = "FAIL"
    $details = $_.Exception.Message.Substring(0, [Math]::Min(200, $_.Exception.Message.Length))
}
$results += Write-TestResult -TestId "T13" -Description "Get-SFClusterHealth via SF HTTP Module (both-EKU cert)" -Expected "PASS" -Actual $actual -Details $details

# T16: SF REST GET /Nodes via PS5.1 with server-only cert (FAIL)
Write-Host "`n--- T16: GET /Nodes via PS5.1 (server-only cert) ---" -ForegroundColor Yellow

$ps51NodesScript = @"
`$ErrorActionPreference = 'Continue'
`$cert = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}

try {
    `$response = Invoke-RestMethod -Uri "$baseUrl$nodesPath" -Certificate `$cert -TimeoutSec 15 -ErrorAction Stop
    Write-Output "PASS|`$(`$response.Items.Count) nodes"
} catch {
    Write-Output "FAIL|`$(`$_.Exception.Message.Substring(0, [Math]::Min(200, `$_.Exception.Message.Length)))"
}
"@

try {
    $ps51NodesResult = powershell.exe -NoProfile -Command $ps51NodesScript 2>&1
    $parts = ($ps51NodesResult | Out-String).Trim().Split('|', 2)
    $actual = $parts[0]
    $details = $parts[1]
} catch {
    $actual = "FAIL"
    $details = "PS 5.1 error"
}
$results += Write-TestResult -TestId "T16" -Description "GET /Nodes via PS5.1 (server-only cert)" -Expected "FAIL" -Actual $actual -Details $details

# T17: SF REST GET /Nodes via PS7 with server-only cert (FAIL)
Write-Host "`n--- T17: GET /Nodes via PS7 (server-only cert) ---" -ForegroundColor Yellow

try {
    $cert = Get-Item "Cert:\CurrentUser\My\$ServerOnlyThumbprint"
    $response = Invoke-RestMethod -Uri "$baseUrl$nodesPath" `
        -Certificate $cert `
        -SkipCertificateCheck `
        -TimeoutSec 15 `
        -ErrorAction Stop
    $actual = "PASS"
    $details = "$($response.Items.Count) nodes returned"
} catch {
    $actual = "FAIL"
    $details = $_.Exception.Message.Substring(0, [Math]::Min(200, $_.Exception.Message.Length))
}
$results += Write-TestResult -TestId "T17" -Description "GET /Nodes via PS7 (server-only cert)" -Expected "FAIL" -Actual $actual -Details $details

# T18: GET /Nodes via curl with server-only cert (PASS)
Write-Host "`n--- T18: GET /Nodes via curl (server-only cert) ---" -ForegroundColor Yellow

try {
    $curlNodes = & curl.exe -s -k `
        -E "CurrentUser\My\$ServerOnlyThumbprint" `
        "$baseUrl$nodesPath" 2>&1
    
    $curlOut = $curlNodes | Out-String
    if ($curlOut -match '"Items"' -or $curlOut -match '"Name"') {
        $actual = "PASS"
        $details = $curlOut.Substring(0, [Math]::Min(200, $curlOut.Length))
    } else {
        $actual = "FAIL"
        $details = "No node data: $($curlOut.Substring(0, [Math]::Min(200, $curlOut.Length)))"
    }
} catch {
    $actual = "FAIL"
    $details = "curl error: $($_.Exception.Message)"
}
$results += Write-TestResult -TestId "T18" -Description "GET /Nodes via curl (server-only cert)" -Expected "PASS" -Actual $actual -Details $details

# ============================================================
# SUMMARY
# ============================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$totalTests = $results.Count
$matchCount = ($results | Where-Object { $_.Match }).Count
$mismatchCount = $totalTests - $matchCount

Write-Host "Total Tests:    $totalTests"
Write-Host "Matched:        $matchCount" -ForegroundColor Green
Write-Host "Mismatched:     $mismatchCount" -ForegroundColor $(if ($mismatchCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

$summary = "`nSUMMARY: $matchCount/$totalTests tests matched expected behavior`n"
foreach ($r in $results) {
    $mark = if ($r.Match) { "✓" } else { "✗" }
    $summary += "  $mark $($r.TestId): $($r.Description) [Expected: $($r.Expected), Got: $($r.Actual)]`n"
}
Add-Content -Path $resultFile -Value $summary

Write-Host $summary
Write-Host "`nResults saved to: $resultFile" -ForegroundColor Cyan
