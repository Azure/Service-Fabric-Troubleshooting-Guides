# Service Fabric Explorer sign-in fails with AADSTS9002326 after upgrade to SF 11.10

Use this TSG for a Service Fabric cluster (classic or managed) that uses Microsoft Entra ID (formerly Azure Active Directory) for client authentication and is running or upgrading to Service Fabric 11.10 or later.

## Symptoms

- After the cluster is upgraded to SF 11.10, users can no longer sign in to Service Fabric Explorer (SFX) in the browser at `https://<cluster_fqdn>:19080/Explorer`.
- The Microsoft Entra sign-in page completes, the browser returns to SFX, and SFX shows the page **Sign-in could not complete** with text similar to:

  > This cluster's Microsoft Entra app registration (client id **&lt;cluster application id&gt;**) does not have the reply URL **https://&lt;cluster_fqdn&gt;:19080/Explorer/index.html** registered under the **Single-page application** platform.

- The browser developer tools console (F12) shows an error from the token request to `login.microsoftonline.com` similar to:

  ```text
  AADSTS9002326: Cross-origin token redemption is permitted only for the 'Single-Page Application' client-type.
  ```

- The same cluster worked with SFX before the upgrade, and PowerShell (`Connect-ServiceFabricCluster -AzureActiveDirectory`), the SDK, and REST API access are not affected.

## Cause

Starting with SF 11.10, SFX signs in by using the Microsoft Authentication Library (MSAL, `@azure/msal-browser`) instead of the deprecated Azure AD Authentication Library (ADAL, `adal-angular`).

- **ADAL** used the OAuth 2.0 implicit grant flow. That flow works with reply URLs that are registered under the **Web** platform of the app registration, which is how most clusters were configured.
- **MSAL** uses the OAuth 2.0 authorization code flow with PKCE. SFX runs entirely in the browser, so it redeems the authorization code by calling Microsoft Entra ID directly from the page script (cross-origin token redemption). Microsoft Entra ID allows cross-origin token redemption only for reply URLs registered under the **Single-page application** (SPA) platform.

A reply URL that is registered only under **Web** therefore worked with SFX before SF 11.10 and is rejected with `AADSTS9002326` after the upgrade. This is a breaking change in the client-side configuration requirements, not a defect in the cluster. The fix is made in the Microsoft Entra app registration; no cluster configuration change is required.

SFX uses the following values from the cluster's Microsoft Entra configuration:

| Item | Value |
|---|---|
| App registration (client ID) used by SFX | The **cluster application** (`clusterApplication` in the `azureActiveDirectory` section of the cluster resource). This is the web application, not the native client application. |
| Reply URL (redirect URI) | The origin and path that SFX was loaded from. By default `https://<cluster_fqdn>:19080/Explorer/index.html` (the gateway redirects `/Explorer` to `/Explorer/index.html`). |
| Required platform for the reply URL | **Single-page application** |

## Confirm that this TSG applies

Confirm all of the following:

1. The cluster is configured for Microsoft Entra ID client authentication.
1. The cluster is running SF 11.10 or later. In SFX this is the **Code Version** on the cluster **Essentials** tab; in the Azure portal it is the cluster **Service Fabric version**.
1. SFX shows the **Sign-in could not complete** page, or the browser console shows `AADSTS9002326`.
1. In the cluster application's app registration, the reply URL shown by SFX is listed under **Web** and not under **Single-page application**.

To get the cluster application ID without opening SFX, query the cluster's Microsoft Entra metadata endpoint. The endpoint does not require authentication.

```powershell
$clusterEndpoint = 'https://<cluster_fqdn>:19080'

# Add -SkipCertificateCheck (PowerShell 7) if the cluster certificate is not trusted by this machine.
$aad = Invoke-RestMethod -Uri "$clusterEndpoint/`$/GetAadMetadata?api-version=1.0"
$aad.metadata | Select-Object tenant, cluster, client, login
```

The `cluster` value is the client ID of the app registration that must be updated.

> [!NOTE]
> If SFX shows **Sign-in failed** with an error code other than `9002326`, or the Microsoft Entra sign-in page itself shows an error (for example `AADSTS50011` for a reply URL that is not registered at all, or `AADSTS50105` for a user that is not assigned to a role), this TSG does not apply. See [Authentication Issue with AAD](./Authentication%20Issue%20with%20AAD.md) and [Configure Azure Active Directory Authentication for Existing Cluster](./Configure%20Azure%20Active%20Directory%20Authentication%20for%20Existing%20Cluster.md).

## Prerequisites

- Permission to update the cluster application's app registration: an owner of the app registration, or a Microsoft Entra role such as **Application Administrator** or **Cloud Application Administrator**.
- The exact reply URL(s) users use to open SFX. The URL shown on the SFX **Sign-in could not complete** page is authoritative. If users reach SFX through more than one host name (for example the Azure-assigned `cloudapp.azure.com` name and a custom DNS name), each one must be registered.

## Mitigation

Move the SFX reply URL(s) from the **Web** platform to the **Single-page application** platform on the **cluster application** app registration. Use either the portal or the script below.

> [!TIP]
> This change can be made **before** upgrading to SF 11.10. Microsoft Entra guidance for migrating from the implicit grant to the authorization code flow is to move the redirect URIs to the **Single-page application** platform and keep the implicit grant settings enabled until every application that uses the registration has been migrated. Validate SFX sign-in on a cluster that is still running a version earlier than SF 11.10 after making the change.

### Option 1: Microsoft Entra admin center or Azure portal

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) or the [Azure portal](https://portal.azure.com).
1. Browse to **Entra ID** > **App registrations** > **All applications**, and open the app registration whose **Application (client) ID** matches the cluster application ID.
1. Select **Authentication**.
1. If the **Web** platform tile shows a banner indicating that the redirect URIs should be migrated, select it, select only the SFX reply URL(s) (for example `https://<cluster_fqdn>:19080/Explorer/index.html`), and select **Configure**. Skip to step 7.
1. Otherwise, select **Add a platform** (or **Add Redirect URI**), choose **Single-page application**, enter the SFX reply URL, and select **Configure**.
1. Under the **Web** platform, delete the same SFX reply URL if it is still listed. Do not remove other reply URLs that other applications rely on.
1. Select **Save** if prompted.
1. Reload SFX in the browser.

### Option 2: Azure CLI script

The script moves one SFX reply URL from **Web** to **Single-page application** on the cluster application and preserves all other reply URLs and the implicit grant settings. Run it from PowerShell after `az login` to the tenant that owns the app registration.

```powershell
$clusterAppId = '<cluster application (client) ID>'
$sfxReplyUrl  = 'https://<cluster_fqdn>:19080/Explorer/index.html'

$appUri = "https://graph.microsoft.com/v1.0/applications(appId='$clusterAppId')"
$app = az rest --method GET --uri "$appUri`?`$select=id,displayName,web,spa" | Out-String | ConvertFrom-Json
if (-not $app) { throw "App registration $clusterAppId was not found." }

Write-Host "App registration: $($app.displayName)"
Write-Host "Current Web reply URLs: $($app.web.redirectUris -join ', ')"
Write-Host "Current SPA reply URLs: $($app.spa.redirectUris -join ', ')"

$webRedirectUris = @($app.web.redirectUris | Where-Object { $_ -and $_ -ne $sfxReplyUrl })
$spaRedirectUris = @(@($app.spa.redirectUris) + $sfxReplyUrl | Where-Object { $_ } | Select-Object -Unique)

$body = @{
    web = @{
        redirectUris          = $webRedirectUris
        homePageUrl           = $app.web.homePageUrl
        logoutUrl             = $app.web.logoutUrl
        implicitGrantSettings = $app.web.implicitGrantSettings
    }
    spa = @{
        redirectUris = $spaRedirectUris
    }
} | ConvertTo-Json -Depth 5

$bodyFile = New-TemporaryFile
try {
    [IO.File]::WriteAllText($bodyFile.FullName, $body)
    az rest --method PATCH --uri $appUri --headers 'Content-Type=application/json' --body "@$bodyFile"
}
finally {
    Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue
}

az rest --method GET --uri "$appUri`?`$select=web,spa" --query '{web: web.redirectUris, spa: spa.redirectUris}'
```

Repeat with each reply URL if users reach SFX through more than one host name.


## New clusters

When you create the Microsoft Entra app registrations for a new cluster, register the SFX reply URL under the **Single-page application** platform. The `SetupApplications.ps1` script in [service-fabric-aad-helpers](https://github.com/Azure-Samples/service-fabric-aad-helpers) does this through the `-SpaApplicationReplyUrl` parameter. See [Set up Microsoft Entra ID for client authentication](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-aad).

## Validation

Confirm all of the following after mitigation:

1. The cluster application's app registration lists the SFX reply URL under **Single-page application** and no longer under **Web**.
1. Open SFX in a new InPrivate or Incognito browser window to avoid cached state, and sign in. SFX loads the cluster dashboard and shows the signed-in user name.
1. Users in the **Admin** role can perform write operations, and users in the **ReadOnly** role can view the cluster.

## Reference

- [Set up Microsoft Entra ID for client authentication](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-creation-setup-aad)
- [Service Fabric Explorer: Migrate auth from ADAL to MSAL (PR #1040)](https://github.com/microsoft/service-fabric-explorer/pull/1040)
