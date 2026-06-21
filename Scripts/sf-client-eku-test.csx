#!/usr/bin/env dotnet-script
// ============================================================================
// sf-client-eku-test.csx
//
// C# script to test client certificate authentication behavior with Service
// Fabric clusters when using certificates with only Server Authentication EKU
// (missing Client Authentication EKU 1.3.6.1.5.5.7.3.2).
//
// IMPORTANT: Each test runs in a SEPARATE PROCESS to prevent Windows SChannel
// TLS session caching from contaminating results. SChannel caches successful
// TLS sessions, so a working connection (e.g. SslStreamCertificateContext) can
// cause a subsequent HttpClientHandler test to succeed when it should fail.
//
// Prerequisites:
//   - .NET 8+ SDK installed
//   - dotnet-script tool: dotnet tool install -g dotnet-script
//   - Client certificate installed in CurrentUser\My certificate store
//
// Usage:
//   dotnet script sf-client-eku-test.csx -- <clusterFqdn> <certThumbprint>
//
// Example:
//   dotnet script sf-client-eku-test.csx -- mycluster.eastus.cloudapp.azure.com ABC123DEF456
//
// Run a single test only (used internally for process isolation):
//   dotnet script sf-client-eku-test.csx -- <clusterFqdn> <certThumbprint> --test 1
//
// See also:
//   Security/certificate-client-authentication-eku-removal-impact.md
// ============================================================================

using System.Diagnostics;
using System.Net.Http;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;

// --- parse arguments ---
if (Args.Count < 2)
{
    Console.WriteLine("Usage: dotnet script sf-client-eku-test.csx -- <clusterFqdn> <certThumbprint>");
    Console.WriteLine("Example: dotnet script sf-client-eku-test.csx -- mycluster.eastus.cloudapp.azure.com ABC123DEF456");
    return;
}

string clusterFqdn = Args[0];
string thumbprint = Args[1].ToUpperInvariant();
string baseUrl = $"https://{clusterFqdn}:19080";
string testPath = "/$/GetClusterHealth?api-version=9.1&timeout=10";

// check if running a single test (child process mode)
int singleTest = 0;
if (Args.Count >= 4 && Args[2] == "--test" && int.TryParse(Args[3], out int t))
{
    singleTest = t;
}

// --- find certificate ---
X509Certificate2 cert = null;
using (var store = new X509Store(StoreName.My, StoreLocation.CurrentUser))
{
    store.Open(OpenFlags.ReadOnly);
    var matches = store.Certificates.Find(X509FindType.FindByThumbprint, thumbprint, false);
    if (matches.Count == 0)
    {
        Console.WriteLine($"ERROR: Certificate with thumbprint {thumbprint} not found in CurrentUser\\My");
        return;
    }
    cert = matches[0];
}

// server cert validation callback (accept self-signed cluster certs for testing)
bool ServerCertValidation(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors)
{
    if (errors == SslPolicyErrors.None) return true;
    // Accept self-signed certs: the cluster's server cert may differ from the client cert being tested.
    // For testing purposes, accept any cert where the only error is untrusted root or name mismatch.
    if (errors == SslPolicyErrors.RemoteCertificateChainErrors || errors == SslPolicyErrors.RemoteCertificateNameMismatch
        || errors == (SslPolicyErrors.RemoteCertificateChainErrors | SslPolicyErrors.RemoteCertificateNameMismatch))
    {
        return true;
    }
    return false;
}

// ============================================================================
// ORCHESTRATOR MODE: spawn each test in its own process
// ============================================================================
if (singleTest == 0)
{
    Console.WriteLine($"Cluster:     {baseUrl}");
    Console.WriteLine($"Thumbprint:  {thumbprint}");
    Console.WriteLine();
    Console.WriteLine($"Subject:     {cert.Subject}");
    Console.WriteLine($"HasPrivKey:  {cert.HasPrivateKey}");
    Console.WriteLine($"NotAfter:    {cert.NotAfter}");

    // display EKU info
    bool hasClientEku = false;
    foreach (var ext in cert.Extensions)
    {
        if (ext is X509EnhancedKeyUsageExtension ekuExt)
        {
            Console.WriteLine("EKU:");
            foreach (var oid in ekuExt.EnhancedKeyUsages)
            {
                string label = oid.Value switch
                {
                    "1.3.6.1.5.5.7.3.1" => "Server Authentication",
                    "1.3.6.1.5.5.7.3.2" => "Client Authentication",
                    _ => oid.FriendlyName
                };
                Console.WriteLine($"  - {label} ({oid.Value})");
                if (oid.Value == "1.3.6.1.5.5.7.3.2") hasClientEku = true;
            }
        }
    }

    if (!hasClientEku)
    {
        Console.WriteLine();
        Console.WriteLine("NOTE: Certificate does NOT have Client Authentication EKU.");
        Console.WriteLine("      Tests below will show which .NET approaches still work.");
    }
    else
    {
        Console.WriteLine();
        Console.WriteLine("NOTE: Certificate HAS Client Authentication EKU. All tests should pass.");
    }

    Console.WriteLine();
    Console.WriteLine("Each test runs in a SEPARATE PROCESS to prevent SChannel TLS session");
    Console.WriteLine("cache from contaminating results between tests.");
    Console.WriteLine();
    Console.WriteLine(new string('=', 70));

    // get the path to this script
    string scriptPath = Path.GetFullPath("sf-client-eku-test.csx");
    // if that doesn't exist, try to find it via the first arg in the process command line
    if (!File.Exists(scriptPath))
    {
        string cmdLine = Environment.CommandLine;
        // look for .csx in the command line
        int csxIdx = cmdLine.IndexOf(".csx", StringComparison.OrdinalIgnoreCase);
        if (csxIdx >= 0)
        {
            int start = cmdLine.LastIndexOf('"', csxIdx);
            if (start < 0) start = cmdLine.LastIndexOf(' ', csxIdx);
            scriptPath = cmdLine.Substring(start + 1, csxIdx + 4 - start - 1).Trim('"');
        }
    }

    // run each test in its own process
    int[] testResults = new int[3]; // 0 = unknown, 1 = PASS, 2 = FAIL
    for (int testNum = 1; testNum <= 3; testNum++)
    {
        var psi = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"script \"{scriptPath}\" -- {clusterFqdn} {thumbprint} --test {testNum}",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var proc = Process.Start(psi);
        string output = await proc.StandardOutput.ReadToEndAsync();
        string errors = await proc.StandardError.ReadToEndAsync();
        await proc.WaitForExitAsync();

        Console.Write(output);
        if (!string.IsNullOrEmpty(errors))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.Write(errors);
            Console.ResetColor();
        }

        if (output.Contains("RESULT: PASS")) testResults[testNum - 1] = 1;
        else testResults[testNum - 1] = 2;
    }

    Console.WriteLine(new string('=', 70));
    Console.WriteLine();
    Console.WriteLine("Summary (each test ran in isolated process - no TLS session cache sharing):");
    Console.WriteLine($"  Test 1 (HttpClientHandler.ClientCertificates):      {(testResults[0] == 1 ? "PASS" : "FAIL")}");
    Console.WriteLine($"  Test 2 (SocketsHttpHandler + Callback, .NET 8+):    {(testResults[1] == 1 ? "PASS" : "FAIL")}");
    Console.WriteLine($"  Test 3 (SslStreamCertificateContext, .NET 8+):      {(testResults[2] == 1 ? "PASS" : "FAIL")}");
    Console.WriteLine();
    Console.WriteLine("If your certificate has only Server Authentication EKU:");
    Console.WriteLine("  - Test 1 should FAIL (SChannel silently drops the certificate)");
    Console.WriteLine("  - Tests 2 and 3 should PASS on .NET 8+ (bypasses SChannel EKU filtering)");
    Console.WriteLine();
    Console.WriteLine("For more information, see:");
    Console.WriteLine("  Security/certificate-client-authentication-eku-removal-impact.md");

    return;
}

// ============================================================================
// CHILD PROCESS MODE: run a single test
// ============================================================================

if (singleTest == 1)
{
    // --- Test 1: HttpClientHandler.ClientCertificates ---
    Console.WriteLine();
    Console.WriteLine($"TEST 1: HttpClientHandler.ClientCertificates (PID {Environment.ProcessId})");
    Console.WriteLine("  Expected with server-only EKU: FAIL (SChannel drops cert)");
    Console.WriteLine();
    try
    {
        var handler = new HttpClientHandler();
        handler.ClientCertificates.Add(cert);
        handler.ServerCertificateCustomValidationCallback = (msg, c, ch, e) => ServerCertValidation(msg, c, ch, e);

        using var client = new HttpClient(handler);
        client.Timeout = TimeSpan.FromSeconds(15);
        var response = await client.GetAsync($"{baseUrl}{testPath}");
        Console.WriteLine($"  HTTP:   {(int)response.StatusCode} {response.StatusCode}");
        if (response.IsSuccessStatusCode)
        {
            string body = await response.Content.ReadAsStringAsync();
            Console.WriteLine($"  Body:   {body.Substring(0, Math.Min(200, body.Length))}...");
            Console.WriteLine("  RESULT: PASS");
        }
        else
        {
            Console.WriteLine("  RESULT: FAIL (server rejected or cert not sent)");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"  ERROR:  {ex.GetType().Name}: {ex.Message}");
        Console.WriteLine("  RESULT: FAIL");
    }
    Console.WriteLine();
}
else if (singleTest == 2)
{
    // --- Test 2: SocketsHttpHandler + LocalCertificateSelectionCallback ---
    Console.WriteLine();
    Console.WriteLine($"TEST 2: SocketsHttpHandler + LocalCertificateSelectionCallback (PID {Environment.ProcessId})");
    Console.WriteLine("  Expected with server-only EKU: PASS on .NET 8+ (SocketsHttpHandler bypasses SChannel filtering)");
    Console.WriteLine();
    try
    {
        var handler = new SocketsHttpHandler();
        handler.SslOptions = new SslClientAuthenticationOptions
        {
            ClientCertificates = new X509CertificateCollection { cert },
            LocalCertificateSelectionCallback = (sender, host, certs, remoteCert, issuers) =>
            {
                Console.WriteLine($"  Callback invoked. Certs available: {certs.Count}");
                return certs.Count > 0 ? certs[0] : null;
            },
            RemoteCertificateValidationCallback = (sender, c, ch, e) => ServerCertValidation(sender, c, ch, e)
        };

        using var client = new HttpClient(handler);
        client.Timeout = TimeSpan.FromSeconds(15);
        var response = await client.GetAsync($"{baseUrl}{testPath}");
        Console.WriteLine($"  HTTP:   {(int)response.StatusCode} {response.StatusCode}");
        if (response.IsSuccessStatusCode)
        {
            string body = await response.Content.ReadAsStringAsync();
            Console.WriteLine($"  Body:   {body.Substring(0, Math.Min(200, body.Length))}...");
            Console.WriteLine("  RESULT: PASS");
        }
        else
        {
            Console.WriteLine("  RESULT: FAIL (server rejected or cert not sent)");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"  ERROR:  {ex.GetType().Name}: {ex.Message}");
        Console.WriteLine("  RESULT: FAIL");
    }
    Console.WriteLine();
}
else if (singleTest == 3)
{
    // --- Test 3: SslStreamCertificateContext (.NET 8+ workaround) ---
    Console.WriteLine();
    Console.WriteLine($"TEST 3: SslStreamCertificateContext (ClientCertificateContext) - .NET 8+ (PID {Environment.ProcessId})");
    Console.WriteLine("  Expected with server-only EKU: PASS (bypasses SChannel filtering)");
    Console.WriteLine();
    try
    {
        var certContext = SslStreamCertificateContext.Create(cert, additionalCertificates: null, offline: true);
        var handler = new SocketsHttpHandler();
        handler.SslOptions = new SslClientAuthenticationOptions
        {
            ClientCertificateContext = certContext,
            RemoteCertificateValidationCallback = (sender, c, ch, e) => ServerCertValidation(sender, c, ch, e)
        };

        using var client = new HttpClient(handler);
        client.Timeout = TimeSpan.FromSeconds(15);
        var response = await client.GetAsync($"{baseUrl}{testPath}");
        Console.WriteLine($"  HTTP:   {(int)response.StatusCode} {response.StatusCode}");
        if (response.IsSuccessStatusCode)
        {
            string body = await response.Content.ReadAsStringAsync();
            Console.WriteLine($"  Body:   {body.Substring(0, Math.Min(200, body.Length))}...");
            Console.WriteLine("  RESULT: PASS");
        }
        else
        {
            Console.WriteLine($"  RESULT: FAIL ({(int)response.StatusCode})");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"  ERROR:  {ex.GetType().Name}: {ex.Message}");
        Console.WriteLine("  RESULT: FAIL");
    }
    Console.WriteLine();
}
