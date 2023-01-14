// This configures a set of core infrastructure required for the deployment of the AVD service
// this includes the vnets, subnets and other core services required for the solution

//This script is deployed using the ResourceGroup scope - so it will require an already existing Resource Group to deploy into
//This is created by the deployment script.

//This will work for both a single subscription as well as a dev/prod subscription - just make sure the config details 
//are correct.

//this bicep will set some defaults - you can either change them in code, or change them via parameters e.g. location

//The deployment script for this resouce is in : ../Scripts/2_0_BuildInfrastructure.ps1

//Set the scope - the RG is created as part of the deployment script
targetScope = 'resourceGroup'

//Parameters
@allowed([
  'dev'
  'prod'
])
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = resourceGroup().location

//CONFIG
module Config '../Config/config.bicep'= {
  name: 'config'
  params: {
    localenv: localenv
    location: location
  }
}

//VARIABLES
var product = 'CORE'
var orgCode = Config.outputs.common.orgCode
var tags = Config.outputs.tags

var bastionName = toLower('${orgCode}-bastion-${product}-${localenv}')
var bastionPIPName = toLower('${orgCode}-bastion-pip-${product}-${localenv}')
//var rtName = toLower('${orgCode}-rt-${product}-${localenv}')

//RESOURCES
// Deploy log analytics
module LogAnalytics '../Modules/module_LogAnalytics.bicep' = {
  name: 'LogAnalytics'
  params: {
    location: location
    tags: tags
    laName: Config.outputs.logAnalytics[localenv].name
  }
}

// Deploy core vnet and subnet
// Note: this will set the VNET DNS setting to a server which does not yet exist - AADDS or AD server is build in step 2
module VnetSnetNSG '../Modules/pattern_Vnet_Subnet_NSG.bicep' = {
  name: 'VnetSnetNSG'
  params: {
    location: location
    tags: tags
    lawID: LogAnalytics.outputs.logAnalyticsID
    vnetObject: Config.outputs.vnetAll[localenv][product]
    newDeployment: true
  }
}

// Deploy Bastion
module Bastion '../Modules/module_Bastion.bicep' = {
  name: 'Bastion'
  params: {
    location: location
    tags: tags
    lawID: LogAnalytics.outputs.logAnalyticsID
    bastionHostName: bastionName
    bastionPublicIPName: bastionPIPName
    bastionVnetName: Config.outputs.vnetCore[localenv][product].vnetName
  }
  dependsOn: [
    VnetSnetNSG
  ]
}

//var vnetConfig = Config.outputs.vnetCore[localenv][Config.outputs.adDomainSettings.vnetConfigID]

//Deploy a route table with route to the internet
// module RouteTableInternet '../Modules/module_UserDefinedRoute.bicep' = {
//   name: 'RouteTableInternet'
//   scope: RG
//   params: {
//     location: location
//     tags: tags
//     udrName: rtName
//     udrRouteName: 'internet'
//     nextHopType: 'Internet'
//     addressPrefix: '0.0.0.0/0'
//   }
// }

// //Apply the Route table to the AD Subnet
// module RouteTableADSnet '../Modules/module_UserDefinedRoute_Apply.bicep' = {
//   name: 'RouteTableADSnet'
//   scope: RG
//   params: {
//     udrID: RouteTableInternet.outputs.udrID
//     vnetName: vnetConfig.vnetName
//     subnetName: vnetConfig.subnets[Config.outputs.adDomainSettings.snetConfigID].name
//     subnetCidr: vnetConfig.subnets[Config.outputs.adDomainSettings.snetConfigID].cidr
    
//   }
// }


