//This pattern is used to deploy a virtual network, add an array of subnets and assign a default NSGs to each subnet.
//This does not deploy a route table or assign it to any subnets

//Requires a vnet object in the form:
// netname: {
//   vnetName: <vnet resource name>
//   vnetCidr: '<cidr>'
//   dnsServers: [<dnsSettings>]
//   RG: '<RG name>'
//   subscriptionID: '<subid>'
//   peerOut: <bool>
//   peerIn: <bool>
//   subnets: {
//     <snet name>: {
//       name: '<snet resource name>'
//       cidr: '<snet cidr>'
//       nsgName: '<nsg name>'
//       nsgSecurityRules: [nsg rules]
//     }
//   }
//   peering: [vnet names list]
// }

//NSG Security Rules example
// nsgSecurityRules: [
//   {
//     name: 'NSG resource rule name'
//     properties: {
//       description: 'Required for worker nodes communication within a cluster.'
//       protocol: '*'
//       sourcePortRange: '*'
//       destinationPortRange: '*'
//       sourceAddressPrefix: 'VirtualNetwork'
//       destinationAddressPrefix: 'VirtualNetwork'
//       access: 'Allow'
//       priority: 100
//       direction: 'Inbound'
//     }
//   }
// ]

@description('Tags for the deployed resources')
param tags object

@description('Geographic Location of the Resources.')
param location string = resourceGroup().location

@description('Optional - Whether this is a new or existing deployment.  Default: false')
param newDeployment bool = false

@description('Optional - ID of the Log Analytics service to send debug info to.  Default: none')
param lawID string = ''

@description('The vnet and subnet object to deploy')
param vnetObject object


//VARIABLES
var subnetList = items(vnetObject.subnets)    //Get the subnets as an array
var vnetName = vnetObject.vnetName
var vnetCidr = vnetObject.vnetCidr
var dnsServers = empty(vnetObject.dnsServers) ? [] : vnetObject.dnsServers


//Create the NSGs for each of the subnets
//Workaround: A resource is evaluated even if it is not deployed, so it needs to have a name, even one not used.
@batchSize(1)
resource NSG 'Microsoft.Network/networkSecurityGroups@2022-01-01'  = [for (subnet,i) in subnetList: if (subnet.value.nsgName != '') {
  name: subnet.value.nsgName != '' ? subnet.value.nsgName : 'none${i}'
  location: location
  tags: tags
  properties: {
    securityRules: subnet.value.nsgSecurityRules
  }
}]

//Set up the vnet (deploy if new deployment only)
resource VNet 'Microsoft.Network/virtualNetworks@2022-01-01' = if (newDeployment) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }

    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [for (subnet,i) in subnetList: {
      name: subnet.value.name
      properties: {
        networkSecurityGroup: subnet.value.nsgName != '' ? {
          location: location
          id: NSG[i].id
        } : {}
        addressPrefix: subnet.value.cidr
        privateEndpointNetworkPolicies: 'Disabled'
      }
    }]
  }
}


//VNET Diagnostics
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  scope: VNet
  name: '${vnetName}-diagnostics'
  properties: {
    workspaceId: lawID
    logs: [
      {
        category: 'VMProtectionAlerts'
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

//NSG Diagnostics
resource NSGDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview'  = [for (subnet,i) in subnetList: if (subnet.value.nsgName != '') {
  scope: NSG[i]
  name: '${subnet.value.nsgName}-diagnostics'
  properties: {
    workspaceId: lawID
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
  }
}]


output vnetID string = VNet.id
output vnetName string = VNet.name
output vnetCIDR string = vnetObject.vnetCidr
output vnetPeerTo array = vnetObject.peering
