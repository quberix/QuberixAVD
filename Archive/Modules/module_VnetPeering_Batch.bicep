//this module extends the VnePeering module by configuring peering from a single vnet to one or move vnets
param localVnetName string
param remoteVnets array = []

//the remoteVnets is of the form:
// [
//   {
//     remoteVnetName: <name>
//     remoteVnetRG: <rg name>
//     remoteVnetSubID: <subscription id>
//   }
// ]

//NOTE:  Can only do bidirectional peering within one module call if both the local and remote VNET existing in the same scope
//       Otherwise, you need to call it twice, one for outbound and one for inbound

//Peer FROM the local network TO the remote network - operates in this SCOPE
module ADCorePeeringOut 'module_VnetPeering.bicep' = [for (vnetPeerObject,i) in remoteVnets: {
  name: 'ADCorePeeringOut${i}'
  params: {
    localVnetName: localVnetName
    remoteVnetName: vnetPeerObject.remoteVnetName
    remoteRG: contains(vnetPeerObject,'remoteVnetRG') ? vnetPeerObject.remoteVnetRG : resourceGroup().name //Assume vnet in the same RG less specified
    remoteSubscriptionID: contains(vnetPeerObject,'remoteSubID') ? vnetPeerObject.remoteSubID : subscription().subscriptionId //Assume vnet in same sub unless specified
    peeringInbound: false
  }
}]

//Now do the reverse and peer FROM the remote network TO the local network - requires a change of SCOPE
module ADCorePeeringIn 'module_VnetPeering.bicep' = [for (vnetPeerObject,i) in remoteVnets: {
  name: 'ADCorePeeringOut${i}'
  scope: resourceGroup(contains(vnetPeerObject,'remoteSubID') ? vnetPeerObject.remoteSubID : subscription().subscriptionId ,contains(vnetPeerObject,'remoteVnetRG') ? vnetPeerObject.remoteVnetRG : resourceGroup().name)
  params: {
    localVnetName: vnetPeerObject.remoteVnetName
    remoteVnetName: localVnetName
    remoteRG: resourceGroup().name //Assume vnet in the same RG less specified
    remoteSubscriptionID: subscription().subscriptionId //Assume vnet in same sub unless specified
    peeringInbound: false
  }
}]
