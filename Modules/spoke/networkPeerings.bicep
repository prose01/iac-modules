@description('Name of source VNET. Resides in the current resource group.')
param vnet1Name string
@description('Resource id of destination VNET.')
param vnet2Id string
@description('Whether to use Vitrual Network Gateways in the remote VNET. This should be true when the destination VNET is the hub. Otherwise false.')
param useRemoteVirtualGateway bool
@description('The name for the VNET peering.')
param peeringName string

resource vnet1 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnet1Name
}

resource peeringHubSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-11-01' = {
  name: peeringName
  parent: vnet1
  properties: {
    remoteVirtualNetwork: {
      id: vnet2Id
    }
    allowForwardedTraffic: true
    allowGatewayTransit: !useRemoteVirtualGateway
    allowVirtualNetworkAccess: true
    useRemoteGateways: useRemoteVirtualGateway
  }
}
