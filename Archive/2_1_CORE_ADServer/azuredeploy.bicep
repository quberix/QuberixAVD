//This is used to deploy a working AD server based on a small scale virtual machine.

//Set the scope - required so this can create the RG as well
targetScope = 'subscription'

//Parameters
@allowed([
  'dev'
  'prod'
])
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'UK South'

@description('The default organisation hosting the application/s.  Default: NHSEI')
param organisation string = 'Quberatron'

@description('The application name.  This forms the first part of resource names e.g. qbx-<product>-<resource>-<environment>.  Default: qbx.')
param orgCode string = 'qbx'

@description('The name of the product being deployed.  This forms the second part of a resource name e.g. <orgCode>-core-<resource>-<environment>.  Default: Core')
param product string = 'adserver'

@description('Additional Tags to apply')
param additionalTags object = { }

//Vars - Resource group names
var rgName = toUpper('${orgCode}-RG-${product}-${localenv}')

//Variables
var tags = Config.outputs.tags

//RESOURCES
//Set up the RG without Tags to start with
resource RG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

//Pull in the Config - can't do this earlier unfortunatly as it needs to be drawn in again an existing RG
module Config '../Config/config.bicep'= {
  name: 'config'
  scope: RG
  params: {
    localenv: localenv
    location: location
    organisation: organisation
    orgCode: orgCode
    product: product
    additionalTags: additionalTags
  }
}

//Update the RG tags because we cannot do that in its initial deployment as we need to deploy
//the config module against the RG and the config module contains the tag content
module RGTag '../Modules/module_UpdateRGTags.bicep'= {
  name: 'RGTag'
  params: {
    rgName: rgName
    location: location
    tags: tags
  }
}

// Get the existing Diagnostic logs as deployed by the core infrastructure
module LogAnalytics '../Modules/module_LogAnalytics_Existing.bicep' = {
  name: 'LogAnalytics'
  scope: RG
  params: {
    diagLAWObject: Config.outputs.logAnalytics[localenv]
  }
}

// Build the vnet and subnet for the AD server
module ADVnetSnetNSG '../Modules/pattern_Vnet_Subnet_NSG.bicep' = {
  name: 'ADVnetSnetNSG'
  scope: RG
  params: {
    location: location
    tags: tags
    lawID: LogAnalytics.outputs.logAnalyticsID
    vnetObject: Config.outputs.vnetAll[localenv][product]
    newDeployment: true
  }
}

//Configure peering between AD vnet and the Core vnet
module ADServerVnetPeering '../Modules/module_VnetPeering_Batch.bicep' = {
  name: 'ADServerVnetPeering'
  scope: RG
  params: {
    localVnetName: ADVnetSnetNSG.outputs.vnetName
    remoteVnets: Config.outputs.vnetADServer[localenv][product].peering
  }
}

//Get the vnet config object
var vnetConfig = Config.outputs.vnetADServer[localenv][Config.outputs.adDomainSettings.vnetConfigID]

// Deploy VM based AD server
module ADServer '../Modules/module_VirtualMachine_Windows.bicep' = {
  name: 'ADServer'
  scope: RG
  params: {
    location: location
    tags: tags
    vmName: toLower('${Config.outputs.adDomainSettings.domainServerVM.nameVMObjectNoEnv}${localenv}')
    vmComputerName: toUpper('${Config.outputs.adDomainSettings.domainServerVM.nameVMNoEnv}${localenv}')
    vmAdminName: 'testuser'
    vmAdminPassword: 'test!!!123test'
    vmSize: Config.outputs.adDomainSettings.domainServerVM.size
    vmImageObject: Config.outputs.adDomainSettings.domainServerVM.imageRef
    vnetConfig: vnetConfig
    snetName: vnetConfig.subnets[Config.outputs.adDomainSettings.snetConfigID].name
    diagObject: Config.outputs.logAnalytics[localenv]
  }
  dependsOn: [
    ADVnetSnetNSG
  ]
}
