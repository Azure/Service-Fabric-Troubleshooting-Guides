# How to Migrate from XStore to the Native Image Store Service

The following steps outline the process for migrating from a specific XStore to the native image store.

## Prerequisites

* **Restriction of image store migration:** Any change to the image store should not be allowed during the migration. If the content is copied from the original image store to the target image store, and before the cluster is switched to the target image store by fabric upgrade; any new changes on the original image store, brought by provision/un-provision/creation/upgrade/deletion, will be lost at the target image store, leading to image store inconsistencies. 

* **Ensure that the current cluster manifest has been provisioned:** It’s just the same as what any fabric upgrade demands. In case of failure of fabric upgrade, the provision of the original cluster manifest is required for the rollback. If it hasn’t been done yet, using the following commands to copy current cluster package to image store:

  ```powershell
  Copy-WindowsFabricClusterPackage -ClusterManifestPath xxx\CurrentClusterManifest.xml -CodePackagePath xxx\CodePackage\WindowsFabricRC.3.3.45.9490.msi -ImageStoreConnectionString "file:C:\ProgramData\Windows Fabric\ImageStore"

  Register-WindowsFabricClusterPackage -ClusterManifestPath CurrentClusterManifest.xml -CodePackagePath WindowsFabricRC.3.3.45.9490.msi
  ```

## Migration steps

1. Prepare two updated cluster manifest files and provision. Update the current cluster manifest by adding the following `ImageStoreService` configuration and setting the `Enabled` flag to `true`. These modifications create the new native image store.

  ```xml
  <Section Name="ImageStoreService"> =
    <Parameter Name="Enabled" Value="true" />
  ```

2. Do the first Fabric upgrade to create the native image store. The purpose of the first fabric upgrade is to create an extra native image store besides the current image store. The new native image store is empty and unused; however, it’s still observable by query the system service.
 
  ```powershell
  Get-WindowsFabricService -ApplicationName fabric:/System 
  ```
 
3. Use image store copy tool to copy the content from source image store to the target native image store. Reference the following example: 

  ```powershell
  ImageStoreCopier.exe /ConnectionEndpoint:"MININT-8MRQ409.redmond.corp.microsoft.com:19000" /CredentialType:X509 /ServerCommonName:"WinfabDevClusterCert" /FindType:"FindBySubjectName" /FindValue:"CN=WinfabDevClusterCert" /StoreLocation:"LocalMachine" /StoreName:"My" /SourceImageStore:"xstore:DefaultEndpointsProtocol=https;AccountName=imagestorecopyer;AccountKey=xxxxx;Container=xstore6"/DestinationImageStore:"fabric:ImageStore"  
  ```

  > [!NOTE]
  > The certificate information above is only an example and depends on the cluster being migrated. Once the copy is completed, a manual comparison between two image stores is strongly recommended. The location of native image store can be found by querying the primary replica: Get-WindowsFabricReplica -PartitionId 00000000-0000-0000-0000-000000003000
 
4. Do a second Fabric upgrade to make the native image store officially connected. Once the upgrade is completed, the verification can be done by invoking image store operation like doing a provision/un-provision/creation/upgrade/deletion. A change of content at native image store is expected.

  Because the tool generates a snapshot file called "imageStoreSnapshot.sp", which contains serialized content objects, you should use the image store tool compare command to verify consistency by comparing the before *and* after view of original image store. When the second upgrade is completed, execute the following command and comparison result will be printed out to the screen:
 
  ```powershell
  ImageStoreCopier.exe /ConnectionEndpoint:"localhost:19000" /SourceImageStore:"xstore:DefaultEndpointsProtocol=https;AccountName=imagestorecopyer;AccountKey=xxxxx;Container=xstore6" /Compare
  ```

  The target manifest should contain `<Section Name="ImageStoreService">`, like the following:

  ```xml
  <Section Name="ImageStoreService">
    <Parameter Name="MinReplicaSetSize" Value="5" />
    <Parameter Name="PlacementConstraints" Value="(NodeTypeName==MN)" />
    <Parameter Name="TargetReplicaSetSize" Value="7" />
  </Section>
  ```

  The target manifest should also contain `<Parameter Name="ImageStoreConnectionString" Value="fabric:ImageStore" />` under the management section, like the following:

  ```xml
  <Parameter Name="ImageStoreConnectionString" Value="fabric:ImageStore" />
  ```
