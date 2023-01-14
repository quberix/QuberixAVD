//Associate a route table with one or more subnets

//Requires a udrSubnets object in the form - this is an extract of the subnet section from the larger standardised network object:
// [
//   {
//     name: 'subnet name'
//     cidr: 'x.x.x.x/x'
//   }]
//Note: Only the subnet name is actually required

@description('ID of the route table to apply')
param udrID string

@description('Name of the Vnet that contains the subnet to apply RT to')
param vnetName string

@description('Name of the Subnet to apply RT to')
param subnetName string

@description('Name of the Subnet to apply RT to')
param subnetCidr string


//Apply tthe UDR to the SNET
resource UDRSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: '${vnetName}/${subnetName}'
  properties: {
    routeTable: {
      id: udrID
    }
    addressPrefix: subnetCidr
  }
}
