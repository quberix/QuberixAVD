//Virtual networking for the UDAL DATA VNET
param dnsSettings object
param subscriptions object
param orgCode string
param product string = 'core'

var defaultRGNoEnv = '${orgCode}-RG-${product}}'
var coreVnetNameNoEnv = '${orgCode}-vnet-${product}}'
var coreSnetNameNoEnv = '${orgCode}-snet-${product}}'
var coreNSGNameNoEnv = '${orgCode}-nsg-${product}}'

//Inbound from AVD (3389-WindowsVirtualDesktop) plus vnet and LB
var avdInboundStandardRulesDev = [
  {
    name: 'Allow-AVD-Service-Inbound'
    properties: {
      description: 'Permit access from the Microsoft AVD service to the desktops (DEV)'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: 'WindowsVirtualDesktop'
      destinationAddressPrefix: '10.100.10.0/21'
      access: 'Allow'
      priority: 500
      direction: 'Inbound'
    }
  }
]

var avdInboundStandardRulesProd = [
  {
    name: 'Allow-AVD-Service-Inbound'
    properties: {
      description: 'Permit access from the Microsoft AVD service to the desktops (PROD)'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: 'WindowsVirtualDesktop'
      destinationAddressPrefix: '10.101.10.0/21'
      access: 'Allow'
      priority: 500
      direction: 'Inbound'
    }
  }
]

var vnets = {
  dev: {
    avd: {
      vnetName: toLower('${coreVnetNameNoEnv}-avd-dev')
      vnetCidr: '10.100.10.0/21'
      dnsServers: dnsSettings.dev.ad
      RG: toUpper('${defaultRGNoEnv}-dev')
      subscriptionID: subscriptions.dev.id
      peerOut: true
      peerIn: true
      subnets: {
        analyst: {
          name: toLower('${coreSnetNameNoEnv}-avd-analyst-dev')
          cidr: '10.100.10.0/24'
          nsgName: toLower('${coreNSGNameNoEnv}-avd-analyst-dev')
          nsgSecurityRules: avdInboundStandardRulesDev
        }
      }
      peering: []
    }
  }
  prod: {
    avd: {
      vnetName: toLower('${coreVnetNameNoEnv}-avd-prod')
      vnetCidr: '10.101.10.0/21'
      dnsServers: dnsSettings.prod.ad
      RG: toUpper('${defaultRGNoEnv}-prod')
      subscriptionID: subscriptions.prod.id
      peerOut: true
      peerIn: true
      subnets: {
        analyst: {
          name: toLower('${coreSnetNameNoEnv}-avd-analyst-prod')
          cidr: '10.101.10.0/24'
          nsgName: toLower('${coreNSGNameNoEnv}-avd-analyst-prod')
          nsgSecurityRules: avdInboundStandardRulesProd
        }
      }
      peering: []
    }
  }
}

output vnets object = vnets
