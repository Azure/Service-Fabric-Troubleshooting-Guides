# How do I know if I am using Containers in my SF service?

You would need to look at all of the ServiceManifest.xml files for your applications. Note that you might have multiple application manifests. One application manifest can reference multiple service manifests. One service manifest can contain multiple code packages. Please take a look at `<CodePackage>`. If you are using Docker/container based services, your service manifest would look like below:

```xml
<?xml version="1.0" encoding="utf-8"?>
<ServiceManifest Name="MISampleConsolePkg"
                 Version="1.0.0"
                 xmlns="http://schemas.microsoft.com/2011/01/fabric"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  ...
  <!-- Code package is your service executable. -->
  <CodePackage Name="Code" Version="1.0.0">
    <EntryPoint>
      <!-- Follow this link for more information about deploying Windows containers to Service Fabric: https://aka.ms/sfguestcontainers -->
      <ContainerHost>
        <ImageName>mycr.azurecr.io/folder/image:latest</ImageName>
      </ContainerHost>
    </EntryPoint>
    <EnvironmentVariables>
      <EnvironmentVariable Name="sfmi_observed_vault" Value="" />
      <EnvironmentVariable Name="sfmi_poll_interval" Value="" />
    </EnvironmentVariables>
  </CodePackage>
  ...
</ServiceManifest>
```

By contrast, if you are using Process based services, your service manifest would look like below:

```xml
<?xml version="1.0" encoding="utf-8"?>
<ServiceManifest Name="MISampleWebPkg"
                 Version="1.0.0"
                 xmlns="http://schemas.microsoft.com/2011/01/fabric"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  ...
  <!-- Code package is your service executable. -->
  <CodePackage Name="Code" Version="1.0.0">
    <EntryPoint>
      <ExeHost>
        <Program>MISampleWeb.exe</Program>
        <WorkingFolder>CodePackage</WorkingFolder>
      </ExeHost>
    </EntryPoint>
    <EnvironmentVariables>
      <EnvironmentVariable Name="sfmi_observed_vault" Value="" />
      <EnvironmentVariable Name="sfmi_observed_secret" Value="" />
      <EnvironmentVariable Name="sfmi_verbose_logging" Value="" />
      <EnvironmentVariable Name="sfmi_poll_interval" Value="" />
      <EnvironmentVariable Name="ASPNETCORE_ENVIRONMENT" Value=""/>
    </EnvironmentVariables>
  </CodePackage>
  ...
</ServiceManifest>
```
