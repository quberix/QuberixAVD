//Create a user defined route and apply that rout to a lsit of subnets (optional)

// The vnetObject is of the standardised form:
// {
//   vnetName: 'name without pre or postfix'     (string)
//   vnetCidr: 'x.x.x.x/xx'                      (string)
//   dnsServers: ['dns server1','dns server 2']  (array)
//   subnets: [
//     {
//        name: 'subnet name'
//        cidr: 'x.x.x.x/x'
//      }
//   ]
// }
//In this module, only the vnetName and the subnets[]/name are actually used

param location string = resourceGroup().location
param tags object
param udrName string
param udrRouteName string
param addressPrefix string

@description('Type of service that the route table will connect to as next-hop')
@allowed([
  'Internet'
  'None'
  'VirtualAppliance'
  'VirtualNetworkGateway'
  'VnetLocal'
])
param nextHopType string

param nextHopIPAddress string = ''    //Only needed if nextHopType is virtual appliance
param disableBgpRoutePropagation bool = false

// @description('A list of vnets and subnets to which the route table should apply.  Note they must all be in the same RG as the vnet/subnet')
// param vnetObject object = {}


resource routeTable 'Microsoft.Network/routeTables@2020-06-01' = {
  name: udrName
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: udrRouteName
        properties: {
          addressPrefix: addressPrefix
          nextHopType: nextHopType
          nextHopIpAddress: nextHopIPAddress != '' ? nextHopIPAddress : json('null')
        }
      }
    ]
    disableBgpRoutePropagation: disableBgpRoutePropagation
  }
}

//Apply the RT to the list of subnets - optional and depends on whether a vnetObject has been provided.
// module subnets 'module_UserDefinedRoute_Apply.bicep' = if (length(vnetObject) > 0) {
//   name: 'udrsubnets'
//   params: {
//     udrID: routeTable.id
//     vnetName: vnetObject.vnetName
//     udrSubnets: vnetObject.subnets
//   }
// }

output udrID string = routeTable.id
