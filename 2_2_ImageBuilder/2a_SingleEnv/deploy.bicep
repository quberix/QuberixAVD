//Set up a single VM based AD server to provide Domain Services to AVD

targetScope = 'subscription'

//Parameters
@allowed([
  'dev'
  'prod'
])
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@maxLength(4)
@description('Product Short Name e.g. QBX - no more than 4 characters')
param productShortName string = 'QBX'

@description('Name of the company owning the resources')
param owner string = 'Quberatron'

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  Product: productShortName
}

@description('The name of the resource group to create for the common image builder components')
param RGImageName string = toUpper('${productShortName}-RG-Images')

// //LAW Resource Group name
// @description ('The name of the Log Analytics Workspace Resource Group')
// param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

// //LAW workspace
// @description('Log Analytics Workspace Name')
// param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

@description('The name of the storage account to create as a software repo for the Image Builder and a place to host its common components')
param repoName string = toLower('${productShortName}stbuilderrepo${localenv}')

@description('The name of the resource group where the Repo storage account is located')
param repoRG string = RGImageName

//Compute Gallery
@description('The Name of the compute gallery')
param computeGalName string = toLower('${productShortName}_CGAL_${localenv}')   //Compute gallery names limited to alphanumeric, underscores and periods

//Name of the Image to create
@description('Name of the Image what will be created and added to the gallery e.g. desktop name like Analyst')
param imageName string = 'testimage'

//Image Template Resource Name
@description('The Name of the compute gallery')
param imageTemplateName string = toLower('${productShortName}-vmi-${imageName}-${localenv}') 

//Image Configuration parameters
@description('The maximum time allowed to build the image (in minutes)')
param buildTimeoutInMinutes int = 300

//The VM type used to build the image.  Traditionally it is a Standard_D2s_v3 (2cpu, 8GB ram) however, if you are building a large image, you may want to use a 
//larger VM type.  Other good VMs to use are: Standard_D4ds_v4 (4cpu, 16GB ram)
@description('The VM used to actually build the image.  Note: This is not the VM that you deploy the image to.  Default: Standard_D2s_v3')
param imageBuilderVMSize string = 'Standard_D2s_v3'

@description('Regions where the image is replicated once built.  Recommended having at least one additional region')
param replicationRegions array = [
  location
  'westeurope'
]

@description('The name of the user assigned identity to use for the image builder')
param userAssignedName string

@description('The resource group that hosts the UMI required for the image builder')
param userAssignedRG string = RGImageName

//to get the details use the powershell:
//Note, best to try and use AVD images with Gen2.  AVD images provide multisession and Gen2 provides best performance.
// $locName = 'uksouth'
// Get-AzVMImagePublisher -Location $locName | Select PublisherName   #Typically MicrosoftWindowsDesktop
// Get-AzVMImageOffer -Location $locName -PublisherName 'MicrosoftWindowsDesktop' | Select Offer  #Typically Windows-10, Windows-11, office-365

// Get-AzVMImageSku -Location $locName -PublisherName 'MicrosoftWindowsDesktop' -Offer 'Windows-10' | Select Skus  #Example win10-22h2-avd-g2
// #OR
// Get-AzVMImageSku -Location $locName -PublisherName 'MicrosoftWindowsDesktop' -Offer 'office-365' | Select Skus  #Example win10-22h2-avd-m365 (includes office 365 apps)

//You can, of course, also use your own custom images by pointing to a gallery image.

@description('The source image used for the image being created')
param sourceImage object = {
  offer: 'office-365'
  publisher: 'MicrosoftWindowsDesktop'
  sku: 'win10-22h2-avd-m365-g2'
  type: 'PlatformImage'
  version: 'latest'
}

@description('Set the disk size to the same size as the base image.')
param diskSizeOverride int = 127

param buildScriptZipName string = 'buildscripts.zip'
param buildScriptContainer string = 'buildscripts'
param buildScriptSasProperties object = {
  signedPermission: 'rl'
  signedResource: 'c'
  signedProtocol: 'https'
  //signedExpiry: dateTimeAdd(utcNow('u'), 'PT20M')
  signedExpiry: dateTimeAdd(utcNow('u'), 'PT180M')
  canonicalizedResource: '/blob/${repoName}/${buildScriptContainer}'
}

param buildSoftwareContainer string = 'repository'
param buildSoftwareSasProperties object = {
  signedPermission: 'rl'
  signedResource: 'c'
  signedProtocol: 'https'
  //signedExpiry: dateTimeAdd(utcNow('u'), 'PT20M')
  signedExpiry: dateTimeAdd(utcNow('u'), 'PT180M')
  canonicalizedResource: '/blob/${repoName}/${buildSoftwareContainer}'
}

param localBuildScriptFolder string = 'C:\\BuildScripts'

//VARIABLES
var buildScriptsSourceURI = '${storageRepo.properties.primaryEndpoints.blob}${buildScriptContainer}/${buildScriptZipName}'
var storageAccountSASTokenScriptBlob = listServiceSas(storageRepo.id, '2021-04-01',buildScriptSasProperties).serviceSasToken
var storageAccountSASTokenSWBlob = listServiceSas(storageRepo.id, '2021-04-01',buildSoftwareSasProperties).serviceSasToken

//var storageAccountSASTokenFile = listServiceSas(storageRepo.id, '2021-04-01',softwareSasProperties).serviceSasToken

//RESOURCES
//Pull in the RG
resource RGImage 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: RGImageName
}

//Pull in the image gallery
resource CGImage 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: computeGalName
  scope: RGImage
}

//Pull in the storage repo
resource storageRepo 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: repoName
  scope: resourceGroup(repoRG)
}

//Create a Gallery Definition
module imageDefinition '../../MSResourceModules/modules/Microsoft.Compute/galleries/images/deploy.bicep' = {
  name: 'imageDefinition'
  scope: RGImage
  params: {
    galleryName: CGImage.name
    location: location
    tags: tags
    name: imageName
    osState: 'Generalized'
    osType: 'Windows'
    imageDefinitionDescription: 'Image Definition for ${imageName}'
    hyperVGeneration: 'V2'
    minRecommendedMemory: 4
    minRecommendedvCPUs: 2
    offer: sourceImage.offer
    publisher: owner
    sku: imageName
  }

}

//Create the Image template
module imageTemplate '../../MSResourceModules/Modules/Microsoft.VirtualMachineImages/imageTemplates/deploy.bicep' = {
  name: 'imageTemplate'
  scope: RGImage

  params: {
    location: location
    tags: tags
    name: imageTemplateName
    imageSource: sourceImage
    userMsiName: userAssignedName
    userMsiResourceGroup: userAssignedRG

    //Build config
    buildTimeoutInMinutes: buildTimeoutInMinutes
    osDiskSizeGB: diskSizeOverride
    vmSize: imageBuilderVMSize

    //Customisation - can be any of File (for copy), Powershell (windows), Shell (linux), WindowsRestart or WindowsUpdate
    //Note, all scripts need to be publically acessible.  Alternativly you need to copy the scripts/artifacts from a private location
    //to the VM itself in order to run them.  This is done using the File customisation step.  the way to look at this is that
    //the buildVM, which is not on your network, needs to be able to see them.
    
    customizationSteps: [
      //Copy the buildscripts.zip from storage blob to the VM using powershell and decompress it installing the AZ modules at the same time
      //replace storagedomain with endpoint blob from the storage account outputs??
      {
        type: 'PowerShell'
        name: 'DownloadExpandBuildScripts'
        runElevated: true
        inline: [
          '$storageAccount = "${repoName}"'
          //'Invoke-WebRequest -Uri "${storageRepo.properties.primaryEndpoints.blob}${buildScriptContainer}/${buildScriptZipName}" -OutFile "${buildScriptZipName}"'
          'Invoke-WebRequest -Uri "${storageRepo.properties.primaryEndpoints.blob}${buildScriptContainer}/${buildScriptZipName}?${storageAccountSASTokenScriptBlob}" -OutFile "${buildScriptZipName}"'
          'New-Item -Path "C:\\BuildScripts" -ItemType Directory -Force'
          'Expand-Archive -Path "${buildScriptZipName}" -DestinationPath "${localBuildScriptFolder}" -Force'
        ]
      }

      //Run the software installer script
      {
        type: 'PowerShell'
        name: 'DownloadAndRunInstallerScript'
        runElevated: true
        inline: [
          'Set-ExecutionPolicy Bypass -Scope Process -Force'
          'C:\\BuildScripts\\InstallSoftware.ps1 "${repoName}" "${storageAccountSASTokenSWBlob}" "${buildSoftwareContainer}" "${localBuildScriptFolder}"'
        ]
      }

      //Run a validation script to ensure the build was successful
      {
        type: 'PowerShell'
        name: 'RunValidationScript'
        runElevated: true
        inline: [
          'C:\\BuildScripts\\ValidateEnvironment.ps1'
        ]
      }

      //Remove the build scripts directory
      {
        type: 'PowerShell'
        name: 'RemoveBuildScriptsDirectory'
        runElevated: true
        inline: [
          'Remove-Item -Path C:\\BuildScripts -Recurse -Force'
        ]
      }

      //Restart the VM
      {
        type: 'WindowsRestart'
        restartTimeout: '30m'
      }

      //Run windows updates
      {
        type: 'WindowsUpdate'
        searchCriteria: 'IsInstalled=0'
        filters: [
          'exclude:$_.Title -like "*Preview*"'
          'include:$true'
        ]
        updateLimit: 500
      }

      //One final restart of the VM
      {
        type: 'WindowsRestart'
        restartTimeout: '30m'
      }
    ]

    //Distribution
    sigImageDefinitionId: imageDefinition.outputs.resourceId
    managedImageName: imageTemplateName
    unManagedImageName: imageTemplateName
    imageReplicationRegions: replicationRegions
      
  }
}

output imageTemplateName string = imageTemplate.outputs.name
output storageURI string = buildScriptsSourceURI
