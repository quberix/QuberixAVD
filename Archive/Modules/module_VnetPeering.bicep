
//Defines peering between two networks
//Bi-directional peering only works if the vnets are in the same resource group
//This can be used, though, in uni-directional mode to establish peering in each way if the scopes are different

//If using it in one-way mode, set the peeringInBound to false and scope the module to the originating vnet
//for single direction in a different scope you need to specify as a minimum:
// - localVnetName
// - remoteVnetName
// - remoteRG

//Parameters - local
@description('The name of the local Virtual Network (from)')
param localVnetName string

@description('The name of the local RG (from)')
param localRG string = resourceGroup().name

@description('Allow forwarded traffic from the remote network')
param localAllowForwarded bool = false

@description('Allow traffic from the remote network to use the gateway in the local one')
param localAllowGatewayTransit bool = false

@description('Allow local traffic to use the remote networks local gateway')
param localUseRemoteGateway bool = false


//Params - remote
@description('The name of the remote Virtual Network (to)')
param remoteVnetName string

@description('The name of the local RG (to)')
param remoteRG string = resourceGroup().name


@description('The name of the local RG (to)')
param remoteSubscriptionID string = subscription().id

@description('Allow local forwarded traffic to the remote network')
param remoteAllowForwarded bool = false

@description('Allow traffic from the local network to use the remote gateway')
param remoteAllowGatewayTransit bool = false

@description('Allow remote traffic to use the local networks gateway')
param remoteUseRemoteGateway bool = false


param peeringOutbound bool = true
param peeringInbound bool = true

resource peerout 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = if (peeringOutbound) {
  name: '${localVnetName}/peer-${remoteVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: localAllowForwarded
    allowGatewayTransit: localAllowGatewayTransit
    useRemoteGateways: localUseRemoteGateway
    remoteVirtualNetwork: {
      id: resourceId(remoteSubscriptionID,remoteRG, 'Microsoft.Network/virtualNetworks', remoteVnetName)
    }
  }
}

resource peerin 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = if (peeringInbound) {
  name: '${remoteVnetName}/peer-${localVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: remoteAllowForwarded
    allowGatewayTransit: remoteAllowGatewayTransit
    useRemoteGateways: remoteUseRemoteGateway
    remoteVirtualNetwork: {
      id: resourceId(localRG, 'Microsoft.Network/virtualNetworks', localVnetName)
    }
  }
}

