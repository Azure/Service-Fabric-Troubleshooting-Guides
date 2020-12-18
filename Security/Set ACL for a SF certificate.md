<code>applys to Windows OS</code>

## How to set ACL for a SF certificate 

For a cluster running on a local dev box you do that by finding the certificate either using certmgr.msc or the relevant mmc snap-in and then right click > All Tasks > Manage Private Keys and then giving read permissions to NETWORK SERVICE.

For remote clusters in Azure, you can do that using a custom script extension on the VMMS of the scale set that will run a PowerShell script that sets up the permissions you want. For example, it could do something like the following:

```PowerShell
$certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -eq $certificateThumbprint}

# Get file path
$certificateFilePath = "C:\Documents and Settings\All Users\Application Data\Microsoft\Crypto\RSA\MachineKeys\" + $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName

# Take ownership of the file so that permissions can be set
takeown /F $certificateFilePath

# Give the NETWORK SERVICE read permissions
$acl = (Get-Item $certificateFilePath).GetAccessControl('Access')
$rule = new-object System.Security.AccessControl.FileSystemAccessRule "NETWORK SERVICE","Read","Allow"
$acl.SetAccessRule($rule)
Set-Acl -Path $certificateFilePath -AclObject $acl
```

**** Refer this On Prem ACL Setting ***

Install the certificates section:- [https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-windows-cluster-x509-security](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-windows-cluster-x509-security)

Now set the access control on this certificate so that the Service Fabric process, which runs under the Network Service account, can use it by running the following script. Provide the thumbprint of the certificate and "NETWORK SERVICE" for the service account. You can check that the ACLs on the certificate are correct by opening the certificate in Start -> Manage computer certificates, and looking at All Tasks-> Manage Private Keys.

```PowerShell
    param
    (
        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$pfxThumbPrint,

        [Parameter(Position=2, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$serviceAccount
    )

    $cert = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object -FilterScript { $PSItem.ThumbPrint -eq $pfxThumbPrint; }

    # Specify the user, the permissions and the permission type
    $permission = "$($serviceAccount)","FullControl","Allow"
    $accessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permission

    # Location of the machine related keys
    $keyPath = Join-Path -Path $env:ProgramData -ChildPath "\Microsoft\Crypto\RSA\MachineKeys"
    $keyName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
    $keyFullPath = Join-Path -Path $keyPath -ChildPath $keyName

    # Get the current acl of the private key
    $acl = (Get-Item $keyFullPath).GetAccessControl('Access')

    # Add the new ace to the acl of the private key
    $acl.SetAccessRule($accessRule)

    # Write back the new acl
    Set-Acl -Path $keyFullPath -AclObject $acl -ErrorAction Stop

    # Observe the access rights currently assigned to this certificate.
    get-acl $keyFullPath| fl
```
