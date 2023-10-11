# Installation of Service Fabric 10.0 SDK fails with error code 0x8013141A

## Problem

- Installation of Service Fabric 10.0 SDK fails with error code 0x8013141A

## Symptoms

- Installation Error is shown

    ![Installation Error](../media/InstallationError.png)
- In log file, the following error is shown

```

```

## Cause

- Strong Name (strongname) c

## Mitigation

- Install Service Fabric 9.1 CU6 SDK
    - [release notes](https://github.com/microsoft/service-fabric/blob/master/release_notes/Service_Fabric_ReleaseNotes_91CU6.md)
    - [sdk download](https://download.microsoft.com/download/b/8/a/b8a2fb98-0ec1-41e5-be98-9d8b5abf7856/MicrosoftServiceFabricSDK.6.1.1851.msi)
    - optional: [runtime download](https://download.microsoft.com/download/b/8/a/b8a2fb98-0ec1-41e5-be98-9d8b5abf7856/MicrosoftServiceFabric.9.1.1851.9590.exe)

## Resolution

The Service Fabric team is planning to fix this in next 10.x Cumulative Update.
