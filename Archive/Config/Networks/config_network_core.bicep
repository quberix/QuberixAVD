//Virtual networking for the QBX Demo Core VNET
param dnsSettings object
param subscriptions object
param orgCode string
param product string = 'core'

var defaultRGNoEnv = '${orgCode}-RG-${product}'
var coreVnetNameNoEnv = '${orgCode}-vnet-${product}'
var coreNSGNameNoEnv = '${orgCode}-nsg-${product}'

module BastionNSGRules '../NSGRules/nsgrules_Bastion.bicep' = {
  name: 'BastionNSGRules'
}


var vnets = {
  dev: {
    '${product}': {
      vnetName: toLower('${coreVnetNameNoEnv}-dev')
      vnetCidr: '10.100.1.0/24'
      dnsServers: dnsSettings.dev.ad
      RG: toUpper('${defaultRGNoEnv}-dev')
      subscriptionID: subscriptions.dev.id
      peerOut: true
      peerIn: true
      subnets: {
        bastion: {
          name: 'AzureBastionSubnet'
          cidr: '10.100.1.0/26'
          nsgName: toLower('${coreNSGNameNoEnv}-bastion-dev')
          routeTable: ''
          nsgSecurityRules: BastionNSGRules.outputs.all
        }
      }
      peering: []
    }
  }
  prod: {
    '${product}': {
      vnetName: toLower('${coreVnetNameNoEnv}-prod')
      vnetCidr: '10.101.1.0/24'
      dnsServers: dnsSettings.prod.ad
      rg: toUpper('${defaultRGNoEnv}-prod')
      subscriptionID: subscriptions.dev.id
      peerOut: true
      peerIn: true
      subnets: {
        bastion: {
          name: 'AzureBastionSubnet'
          cidr: '10.101.1.0/26'
          nsgName: toLower('${coreNSGNameNoEnv}-bastion-prod')
          routeTable: ''
          nsgSecurityRules: BastionNSGRules.outputs.all
        }
      }
      peering: []
    }
  }
}



output vnets object = vnets
