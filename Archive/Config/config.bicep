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
param product string = 'core'

@description('the domain name being used to deploy resources to.  Default: quberix.co.uk')
param domain string = 'quberix.co.uk'

@description('Object of additional tags to add.  Optional.  Default: {} (empty object)')
param additionalTags object = {}

//VARIABLES
//group together the common settings
var commonSettings = {
  organisation: organisation
  orgCode: orgCode
  product: product
  location: location
  environment: toLower(localenv)
  domainName: domain
}

//More for reference, this is a list of the default tags being deployed on each resource.
var defaultTags = union({
  Environment: toUpper(localenv)
  Product: toUpper(product)
  Owner: toUpper(organisation)
  Criticality: toLower(localenv) == 'prod' ? 'Tier 1' : 'Tier 2'
}, additionalTags)


//List of all subscriptions by environmental reference
var subscriptions = {
  dev: {
    name: 'UDAL Training'
    id: '7c235ed2-aade-4f4c-a9d3-78f332fb5aee'
  }
  prod: {
    name: 'UDAL Training'
    id: '7c235ed2-aade-4f4c-a9d3-78f332fb5aee'
  }
}

//DNS Settings for various DNS services.  this will be the DNS IP addresses of any deployed AADDS or AD server
var dnsServers = {
  dev: {
    ad: [
      '10.100.0.5'    //The VM running AD and the DNS services will be given this fixed IP address
    ]
  }
  prod: {
    ad: [
      '10.101.0.5'    //The VM running AD and the DNS services will be given this fixed IP address
    ]
  }
}

//Log Analytics Settings
var logAnalytics = {
  dev: {
    rg: toUpper('${orgCode}-RG-CORE-DEV')
    name: toLower('${orgCode}-law-core-dev')
    storageName: toLower('${orgCode}stcorediagdev')
    subscription: subscriptions.dev.id
  }
  prod: {
    rg: toUpper('${orgCode}-RG-CORE-PROD')
    name: toLower('${orgCode}-law-core-prod')
    storageName: toLower('${orgCode}stcorediagprod')
    subscription: subscriptions.prod.id
  }
}

var adDomainSettings = {
  domainName: domain
  domainNameShort: toUpper(orgCode)
  identityKeyVault: 'coreIdentity'
  localAdminUserKVKey: 'localAdminUsername'
  localAdminPasswordKVKey: 'localAdminPassword'
  domainAdminUserKVKey: 'domainAdminUser'
  domainAdminPasswordKVKey: 'domainAdminPassword'
  domainServerVM: {
    nameVMObjectNoEnv: toLower('${orgCode}-vm-adserver')
    nameVMNoEnv: toLower('${orgCode}ADS1')
    imageRef: {
      offer: 'WindowsServer'
        publisher: 'MicrosoftWindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
    }
    size: 'Standard_B2s'
  }
  vnetConfigID: 'adserver'
  snetConfigID: 'adserver'
}

var systemKeyVaults = {
  dev: {
    coreIdentity: {
      name: toLower('${orgCode}-kv-identity-dev')
      subscription: subscriptions.dev.id
      RG: toUpper('${orgCode}-RG-CORE-DEV')
    }
  }
  prod: {
    coreIdentity: {
      name: toLower('${orgCode}-kv-identity-prod')
      subscription: subscriptions.prod.id
      RG: toUpper('${orgCode}-RG-CORE-PROD')
    }
  }
}

//Bastion Settings - default settings for the Bastion
var coreBastionConfig = {
  name: toLower('${orgCode}-bastion-dev')
  sku: 'Basic'
  pipName: toLower('${orgCode}-pip-bastion-dev')
}

// var commonVMConfigs = {
//   imageGallery: {
//     sharedImageGallerySubscriptionID: subscriptions.udal[localenv].id
//     sharedImageGalleryRG: toUpper('${application}-RG-IMAGES-${localenv}')
//     sharedImageGalleryName: toLower('${application}_sig_${localenv}')
//   }
//   windows: {
//     //Makes up the start and end of a wrapper around the VM/VMSS - XML
//     //${wadcfgxstart}<resource specific>${wadcfgxend}
//     //e.g. base64(${wadcfgxstart}/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/virtualMachines/test-vm-dev${wadcfgxend})
//     vmLogs_Start: '${wadlogs}${wadperfcounters1}${wadperfcounters2}<Metrics resourceId="'
//     vmLogs_End: '"><MetricAggregation scheduledTransferPeriod="PT1H"/><MetricAggregation scheduledTransferPeriod="PT1M"/></Metrics></DiagnosticMonitorConfiguration></WadCfg>' 
//   }    
// }

// //Role Assignment Configuration
// var roleAssignmentConfig = {
//   StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
// }


// //Peering Settings - this sets the default config for the majority of the peering on the platform
// var peeringConfig = {
//   trafficToRemote: true
//   trafficForwardedFromRemote: false
//   useLocalGateway: false
//   useRemoteGateway: false
// }

//Default NSG Rules


//AD Server
module ADServerVnet './Networks/config_network_adserver.bicep' = {
  name: 'ADServerVnet'
  params: {
    orgCode: orgCode
    product: 'adserver'
    subscriptions: subscriptions
  }
}

//Core networks
module CoreVnet './Networks/config_network_core.bicep' = {
  name: 'CoreVnet'
  params: {
    orgCode: orgCode
    product: 'core'
    dnsSettings: dnsServers
    subscriptions: subscriptions
  }
}

//AVD Networks
module AVDVnets './Networks/config_network_avd.bicep' = {
  name: 'AVDVnets'
  params: {
    orgCode: orgCode
    product: 'avd'
    dnsSettings: dnsServers
    subscriptions: subscriptions
  }
}


// //Pull all the vnets into a single object
var vnetConfigs = union(ADServerVnet.outputs.vnets,CoreVnet.outputs.vnets,AVDVnets.outputs.vnets)

output tags object = defaultTags
output common object = commonSettings
output subscriptions object = subscriptions
output logAnalytics object = logAnalytics
output DNS object = dnsServers
output systemKeyvaults object = systemKeyVaults
output adDomainSettings object = adDomainSettings
output coreBastionConfig object = coreBastionConfig
output vnetAll object = vnetConfigs
output vnetADServer object = ADServerVnet.outputs.vnets
output vnetCore object = CoreVnet.outputs.vnets
output vnetAVD object = AVDVnets.outputs.vnets

// output roleAssignmentConfig object = roleAssignmentConfig
// output vnetCore object = CoreVnets.outputs.configVnetCore
// output vnetData object = DataVnets.outputs.configVnetData
// output vnetAVD object = AVDVnets.outputs.configVnetAVD
// output vnetAVDCore object = AVDVnets.outputs.configVnetAVDCore
// output vnetIDE object = IDEVnets.outputs.configVnetIDE

// output vnetPeering object = peeringConfig
// output coreFirewallConfigNoEnv object = coreFirewallDetailsCommon
// output coreFirewallConfig object = coreFirewallConfig
// output commonVMSettings object = commonVMConfigs
