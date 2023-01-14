// Deploys the common infrastrcture required to support the Image Builder.  

//Typically this is deployed ONLY to a single environment, typically DEV.

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
param productShortName string

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  Product: productShortName
}

@description('The name of the resource group to create for the common image builder components')
param RGImageName string = toUpper('${productShortName}-RG-Images-${localenv}')

@description('Deploy the Image Builder repository')
param deployRepo bool = true

@description('The name of the storage account to create as a software repo for the Image Builder and a place to host its common components')
param repoName string = toLower('${productShortName}stbuilderrepo${localenv}')  //Storage names are alphanumeric only

@description('The name of the container to hold the scripts used to build the Image Builder')
param blobContainerBuilderCommon string = 'buildscripts'

@description('The name of the container to hold the software to be installed by the Image Builder')
param blobContainerSoftware string = 'repository'

@description('The Name of the compute gallery')
param computeGalName string = toLower('${productShortName}_CGAL_${localenv}')   //Compute gallery names limited to alphanumeric, underscores and periods

//LAW Resource Group name
@description ('The name of the Log Analytics Workspace Resource Group')
param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

//LAW workspace
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

//Build a software repository

//Create the RG
resource RGImages 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGImageName
  location: location
  tags: tags
}

//Retrieve the CORE Log Analytics workspace
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LAWorkspaceName
  scope: resourceGroup(RGLAW)
}

//Create the storage account required for the script which will build the ADDS server
module RepoStorage '../../MSResourceModules/modules/Microsoft.Storage/storageAccounts/deploy.bicep' = if (deployRepo) {
  name: 'RepoStorage'
  scope: RGImages
  params: {
    location: location
    tags: tags
    name: repoName
    allowBlobPublicAccess: true   //Permits access from the deploying script
    publicNetworkAccess: 'Enabled'
    diagnosticLogsRetentionInDays: 7
    diagnosticWorkspaceId: LAWorkspace.id
    storageAccountSku: 'Standard_LRS'
    blobServices: {
      containers: [
        {
          name: blobContainerBuilderCommon
          publicAccess: 'None'
        }
        {
          name: blobContainerSoftware
          publicAccess: 'None'
        }
      ]
      diagnosticWorkspaceId: LAWorkspace.id
    }
    // fileServices: {
    //   shares: [
    //     {
    //       name: fileShareRepository
    //     }
    //   ]
    //   diagnosticWorkspaceId: LAWorkspace.id
    // }

    // networkAcls: {
    //   bypass: 'AzureServices'
    //   defaultAction: 'Deny'
    //   ipRules: [
    //     {
    //       action: 'Allow'
    //       value: localScriptIPAddress
    //     }
    //   ]
    //   virtualNetworkRules: [
    //     {
    //       action: 'Allow'
    //       id: IdentityVnet.outputs.subnetResourceIds[indexOf(IdentityVnet.outputs.subnetNames, IDSnetADName)]
    //     }
    //   ]
    // }
  }
}

//Build the Compute Gallery
module galleries '../../MSResourceModules/modules/Microsoft.Compute/galleries/deploy.bicep' = {
  name: computeGalName
  scope: RGImages
  params: {
    location: location
    tags: tags
    name: computeGalName
    // roleAssignments: [   //Builder will need to write here and VMSS will need to be able to read it
    //   {
    //     principalIds: [
    //       '<managedIdentityPrincipalId>'
    //     ]
    //     principalType: 'ServicePrincipal'
    //     roleDefinitionIdOrName: 'Reader'
    //   }
    // ]
    
  }
}

output storageRepoID string = RepoStorage.outputs.resourceId
output storageRepoName string = RepoStorage.outputs.name
output storageRepoRG string = RepoStorage.outputs.resourceGroupName
output storageRepoBuilderContainer string = blobContainerBuilderCommon
output storageRepoSoftwareContainer string = blobContainerSoftware
