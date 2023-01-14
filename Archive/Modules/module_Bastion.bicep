//configure a Bastion including its subnet, public IP, the bastion itself and its diagnostics

//PARAMETERS
@description('Tags for the deployed resources')
param tags object

@description('Geographic Location of the Resources.')
param location string = resourceGroup().location

@description('Name of the bastion host')
param bastionHostName string

@description('Name of the bastion public ip address')
param bastionPublicIPName string

@description('Name of the bastion public ip address')
@allowed([
  'Basic'
  'Standard'
])
param bastionSku string = 'Basic'

@description('Optional: The Vnet to which Bastion subnet is to be configured.  If not configured bastionSubnetID must be configured')
param bastionVnetName string = ''

@description('Optional - ID of the Log Analytics service to send debug info to.  Default: none')
param lawID string = ''

//VARIABLES

//Pull in the existing vnet if bastionVnetName is specified
resource BastionVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing =  {
  name: bastionVnetName
}

//Pull in the subnet
resource BastionSnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: 'AzureBastionSubnet'
  parent: BastionVnet
}

//Create the Public IP Address
module BastionPIP 'module_PublicIPAddress.bicep' = {
  name: bastionPublicIPName
  params: {
    location: location
    tags: tags
    publicIPAddressName: bastionPublicIPName
    publicIPSKU: 'Standard'
    publicIPType: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionHostName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: BastionSnet.id
          }
          publicIPAddress: {
            id: BastionPIP.outputs.id
          }
        }
      }
    ]
  }
}


//Bastion Diagnostics
resource bastionDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = if (lawID != '') {
  scope: bastionHost
  name: '${bastionHostName}-Bastion-diagnostics'
  properties: {
    workspaceId: lawID
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
  }
}
