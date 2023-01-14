//Virtual networking for the UDAL DATA VNET
param subscriptions object
param orgCode string
param product string = 'adserver'

var defaultRGNoEnv = '${orgCode}-RG-${product}'
var coreVnetNameNoEnv = '${orgCode}-vnet-${product}'
var coreSnetNameNoEnv = '${orgCode}-snet-${product}'
var coreNSGNameNoEnv = '${orgCode}-nsg-${product}'
var coreNSGRTNoEnv = '${orgCode}-rt-${product}'

module ADServerNSGRules '../NSGRules/nsg_rules_AD.bicep' = {
  name: 'ADServerNSGRules'
}


var vnets = {
  dev: {
    '${product}': {
      vnetName: toLower('${coreVnetNameNoEnv}-dev')
      vnetCidr: '10.100.0.0/24'
      dnsServers: []  //DNS servers are set to none, as AD will provide those DNS settings
      RG: toUpper('${defaultRGNoEnv}-dev')
      subscriptionID: subscriptions.dev.id
      peerOut: true
      peerIn: true
      subnets: {
        adserver: {
          name: toLower('${coreSnetNameNoEnv}-adserver-dev')
          cidr: '10.100.0.0/26'
          nsgName: toLower('${coreNSGNameNoEnv}-adserver-dev')
          routeTable: {
            name: toLower('${coreNSGRTNoEnv}-adserver-dev')
          }
          nsgSecurityRules: ADServerNSGRules.outputs.inbound
        }
      }
      peering: [
        {
          remoteVnetName: toLower('${orgCode}-vnet-core-dev')      //Vnet name to peer to CORE vnet
          remoteVnetRG: toUpper('${orgCode}-RG-CORE-DEV')
        }
      ]
    }
  }
  prod: {
    '${product}': {
      vnetName: toLower('${coreVnetNameNoEnv}-prod')
      vnetCidr: '10.101.0.0/24'
      dnsServers: []  //DNS servers are set to none, as we need AD up and running for the DNS service to work
      rg: toUpper('${defaultRGNoEnv}-prod')
      subscriptionID: subscriptions.dev.id
      peerOut: true
      peerIn: true
      subnets: {
        adserver: {
          name: toLower('${coreSnetNameNoEnv}-adserver-prod')
          cidr: '10.101.0.0/26'
          nsgName: toLower('${coreNSGNameNoEnv}-adserver-prod')
          routeTable: toLower('${coreNSGRTNoEnv}-adserver-prod')
          nsgSecurityRules: ADServerNSGRules.outputs.inbound
        }
      }
      peering: [
        {
          remoteVnetName: toLower('${orgCode}-vnet-core-prod')      //Vnet name to peer to CORE vnet
          remoteVnetRG: toUpper('${orgCode}-RG-CORE-PROD')
        }
      ]
    }
  }
}



output vnets object = vnets
