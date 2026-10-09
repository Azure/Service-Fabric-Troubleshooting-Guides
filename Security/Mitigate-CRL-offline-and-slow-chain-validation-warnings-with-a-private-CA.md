# Mitigating CRL offline / slow certificate chain validation warnings with a private (internal) CA

## Symptoms

On a Service Fabric cluster whose certificates are issued by a **private / internal Certificate Authority** (for example an Active Directory Certificate Services PKI), you may see one or more of the following, continuously, on some or all nodes:

- Service Fabric Explorer (SFX) shows a **Warning** health state on nodes, sourced from `SecurityApi_CertGetCertificateChain`.
- `Microsoft-ServiceFabric/Admin` event log entries:

  ```text
  CertGetCertificateChain is slow, duration = 32.527, threshold = 10.000
  ignore error 0x80092013:certificate revocation list offline
  ```

- `certutil -verify` on a node reports:

  ```text
  The revocation function was unable to check revocation because the revocation server was offline. 0x80092013 (CRYPT_E_REVOCATION_OFFLINE)
  Revocation check skipped -- server offline
  Certificate is valid
  ```

The certificate chain itself **builds correctly** (leaf → issuing CA → root) and the certificate is otherwise valid — the only problem is that the runtime cannot reach the certificate's revocation endpoints (CRL / OCSP), so each chain build stalls waiting on a network timeout before giving up.

> This guide is a companion to [How to mitigate SecurityApi_CertGetCertificateChain health warning (CTL accessibility issue or CRL slow/offline)](./SecurityApi_CertGetCertificateChain%20-%20CTL%20accessibility%20-%20CRL%20slow%20warnings.md). That guide covers the general flag values; this one focuses on the **private-CA / locked-down-egress** scenario and the exact behavioral difference between the two Security settings.

## Background: how Service Fabric validates the certificate chain

When Service Fabric loads the cluster certificate (and on every mutual-TLS handshake between nodes, and for client authentication), it calls the Win32 CryptoAPI [`CertGetCertificateChain`](https://learn.microsoft.com/windows/win32/api/wincrypt/nf-wincrypt-certgetcertificatechain) to build and validate the chain. By default this includes a **revocation check** (default `dwFlags` = `0x40000000` = `CERT_CHAIN_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT`).

To check revocation, CryptoAPI reads the certificate's **CRL Distribution Point (CDP)** and **Authority Information Access (AIA / OCSP)** extensions and downloads the CRL / queries OCSP from those URLs. If those endpoints are unreachable, the download **blocks until it times out** (this is the `CertGetCertificateChain is slow` warning), then returns `CRYPT_E_REVOCATION_OFFLINE (0x80092013)`.

## Why private / internal CAs hit this — and public CAs usually don't

This is the crux of the issue and why the mitigation is so commonly needed specifically for private CAs:

| | Public / commercial CA | Private / internal (enterprise) CA |
| --- | --- | --- |
| CDP / OCSP URLs | Internet-reachable HTTP (e.g. `http://crl.<vendor>.com/...`) | **Internal-only** URLs — internal HTTP (`http://pki.<corp>.internal/...`) and/or **LDAP into the AD forest** (`ldap:///CN=...,DC=<forest>,DC=net`) |
| Reachable from an Azure VM with normal outbound? | Yes — revocation resolves in milliseconds | **No** — the endpoint only resolves/routes from inside the corporate network |
| Result on a locked-down SF subnet | Works | CRL/OCSP fetch **times out** → slow chain build + `revocation offline` |

Service Fabric clusters are frequently deployed into **locked-down subnets**: no outbound internet, restrictive NSGs/firewalls, and no line-of-sight (routing/DNS) to the on-premises AD / PKI that issues the certificates. A private CA embeds its **internal** CDP/AIA URLs into every issued certificate, so a node in such a subnet cannot reach them. Every certificate validation therefore pays the full revocation-retrieval timeout, producing the slow-chain and revocation-offline warnings — even though the certificate is perfectly valid and the chain builds.

Public-CA clusters rarely see this because their CDP/OCSP endpoints are on the public internet, which the node can usually reach.

## The two Security settings — and the critical difference between them

Both settings live under the `Security` section of `fabricSettings` and are documented under **Certificate configuration rules** in [X.509 certificate-based authentication in Service Fabric clusters](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificates).

### `IgnoreCrlOfflineError`  (boolean, default `false`)

> "Represents a shortcut for suppressing a 'revocation offline' chain building error status (or a subsequent chain policy validation error status)." — Microsoft Learn

This **suppresses the error** so the cluster does not fail authentication or block on the `revocation offline` status. It is what keeps the cluster **up and healthy** when the PKI is unreachable.

**What it does NOT do:** it does **not** stop CryptoAPI from *attempting* the CRL/OCSP download. The outbound fetch still happens and still times out, so the **`CertGetCertificateChain is slow` latency and warnings persist**. In field data, applying `IgnoreCrlOfflineError=true` alone left the slow-chain warnings being logged continuously.

### `CrlCheckingFlag`  (string → UINT, default `0x40000000`)

> "The value of this setting is used by Service Fabric to mask out certificate chain status errors by changing the behavior of chain building; it's passed in to the Win32 CryptoAPI `CertGetCertificateChain` call as the 'dwFlags' parameter... **A value of 0 forces the Service Fabric runtime to ignore any trust status errors — this isn't recommended, as its use would constitute a significant security exposure.**" — Microsoft Learn

`CrlCheckingFlag` controls the revocation-check `dwFlags`. Setting it so that the revocation-check bits are cleared means CryptoAPI **no longer requests revocation retrieval**, so the CRL/OCSP download is not attempted, the timeout does not occur, and the **slow-chain warnings stop**. This is the setting that actually removes the *slowness*.

Common values (see the companion TSG for the full matrix):

| Value | Meaning | Effect |
| --- | --- | --- |
| `0x40000000` | default (`REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT`) | full revocation check — the source of the timeouts |
| `0x80000000` | `CERT_CHAIN_REVOCATION_CHECK_CACHE_ONLY` | only use cached CRLs, don't download — **narrowest** option that stops the download |
| `0` | ignore **all** trust status errors | stops the download **but also disables all chain trust validation — broadest exposure** |

### Summary of the difference

| Setting | Stops the auth-blocking **error**? | Stops the **CRL fetch timeout / slowness**? |
| --- | --- | --- |
| `IgnoreCrlOfflineError=true` | ✅ yes | ❌ no |
| `CrlCheckingFlag` (revocation bits cleared) | ✅ yes | ✅ yes |

## Mitigation

### Preferred fix — make the revocation endpoints reachable (no security tradeoff)

Before changing validation behavior, prefer restoring reachability to the private PKI so revocation continues to be checked:

- Open outbound access (and DNS resolution) from the cluster subnet to the CA's **CDP / AIA / OCSP** endpoints — typically the internal HTTP PKI host (TCP 80/443) and, if the CDP uses LDAP, the AD forest domain controllers (TCP 389/636).
- Or publish an **internal CRL mirror** reachable from the subnet.

This keeps revocation checking intact and eliminates both the error and the slowness with no security compromise.

### Mitigation when the PKI genuinely cannot be reached (air-gapped / locked egress)

If the endpoints cannot be made reachable, relax revocation checking. To eliminate **both** the error **and** the slowness, set **both** settings — `CrlCheckingFlag` to stop the download, and `IgnoreCrlOfflineError` as a defense-in-depth guard for any residual offline status.

ARM / `fabricSettings` JSON:

```json
"fabricSettings": [
    {
        "name": "Security",
        "parameters": [
            {
                "name": "CrlCheckingFlag",
                "value": "0"
            },
            {
                "name": "IgnoreCrlOfflineError",
                "value": "true"
            }
        ]
    }
]
```

Cluster manifest (for clusters still managed via manifest XML):

```xml
  <Section Name="Security">
    <Parameter Name="CrlCheckingFlag" Value="0" />
    <Parameter Name="IgnoreCrlOfflineError" Value="true" />
  </Section>
```

Apply as a configuration upgrade and let it roll out to every node. After it converges, the `CertGetCertificateChain is slow` and `certificate revocation list offline` entries should stop and the `SecurityApi_CertGetCertificateChain` warning should clear.

> **Prefer the narrowest value.** `CrlCheckingFlag = "0"` is the simplest and is what most reliably clears the warnings, but per Microsoft Learn it makes Service Fabric ignore **all** chain trust status errors. If your only unreachable dependency is revocation (CRL/OCSP), prefer `CrlCheckingFlag = "0x80000000"` (`CACHE_ONLY`) — it stops the download while still enforcing the rest of chain validation. Test in a non-production cluster to confirm it clears the warnings in your environment before using the broader `0`.

## Security compromises this causes

Relaxing revocation checking is a real security tradeoff — apply it deliberately, scoped to environments where the PKI is genuinely unreachable:

- **Revoked certificates will not be detected.** With revocation checking disabled/ignored, if the cluster, server, or client certificate is compromised and the CA **revokes** it, Service Fabric will **not** learn of the revocation and will continue to accept the certificate. Revocation is the mechanism to invalidate a cert before its expiry; you are turning it off.
- **`CrlCheckingFlag = 0` is the broadest exposure.** It masks *all* chain trust status errors, not just revocation — Microsoft Learn explicitly calls this "a significant security exposure." A mistrusted/misconfigured chain error that would normally be caught is also suppressed. Prefer `CACHE_ONLY` (`0x80000000`) when it is sufficient.
- **Cluster-wide scope.** These are `Security`-section settings; they affect **every** certificate validation the runtime performs — inter-node (cluster) TLS, management endpoint (server) auth, and client auth — not just one certificate.
- **`IgnoreCrlOfflineError` is narrower but still weakens posture.** It only suppresses the *offline* condition (it does not accept a *positively revoked* cert that a reachable CRL would report), which is why it is the safer of the two — but on its own it does not remove the performance/slowness symptom.

### When to use / when not to use

- **Use** when certificates are issued by a private/internal CA whose CDP/OCSP endpoints are unreachable from the cluster subnet (air-gapped, no outbound internet, no route to on-prem AD/PKI) and the network **cannot** be opened; or as a temporary mitigation during a transition between PKIs. This matches Microsoft Learn's stated "when to use": local/testing, developer certificates not backed by a proper PKI, or air-gapped environments / when the PKI is known to be inaccessible.
- **Do not use** as a default or a shortcut when the endpoints *could* be made reachable — open the network path instead. Do not use `CrlCheckingFlag = 0` when a narrower value (`CACHE_ONLY`) clears the warnings.

## Verify

On a node, confirm the chain still builds and observe the revocation behavior:

```powershell
# Build/validate the chain from the store by thumbprint (add -urlfetch to force a live revocation fetch)
certutil -v -urlfetch -verifystore MY "<cluster-cert-thumbprint>"
#  Before mitigation: CDP/OCSP lines show 'Failed ... Time elapsed' and CRYPT_E_REVOCATION_OFFLINE
#  After CrlCheckingFlag change: SF no longer requests revocation, so the slow-chain warnings stop

# Confirm the issuing CA + root are present locally (chain must build regardless of the flags)
Get-ChildItem Cert:\LocalMachine\CA, Cert:\LocalMachine\Root

# Cluster health should return to Ok after the config upgrade converges
Connect-ServiceFabricCluster
Get-ServiceFabricClusterHealth
```

> Note: `CrlCheckingFlag`/`IgnoreCrlOfflineError` relax **revocation** checking. They do **not** substitute for installing the issuing CA chain — the certificate chain must still build (issuing CA in `LocalMachine\CA`, root in `LocalMachine\Root`, or delivered via the VM scale set's Key Vault `osProfile.secrets`). A missing issuer produces a *partial chain* error, which is independent of revocation and is not cleared by these settings.

## References

- [X.509 certificate-based authentication in Service Fabric clusters — Certificate configuration rules](https://learn.microsoft.com/azure/service-fabric/cluster-security-certificates) (`CrlCheckingFlag`, `IgnoreCrlOfflineError`)
- [Customize Service Fabric cluster settings — Security section](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-fabric-settings)
- [Service Fabric cluster security scenarios](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-security)
- [Win32 `CertGetCertificateChain` (dwFlags)](https://learn.microsoft.com/windows/win32/api/wincrypt/nf-wincrypt-certgetcertificatechain)
- Companion TSG: [How to mitigate SecurityApi_CertGetCertificateChain health warning (CTL accessibility issue or CRL slow/offline)](./SecurityApi_CertGetCertificateChain%20-%20CTL%20accessibility%20-%20CRL%20slow%20warnings.md)
- Related: [Install intermediate certificates](./Install%20intermediate%20certificates.md)
