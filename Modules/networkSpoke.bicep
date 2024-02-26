@description('Name of virtualNetwork')
param projectName string

@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'DEV'
  'TEST'
  'PROD'
])
param environmentType string

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

@description('VNET IP address range in CIDR notation')
param ipAddressRange string

@description('Obtained from the networkHubParameters module.')
param hubResourceGroupName string

@description('Obtained from the networkHubParameters module.')
param hubVnetName string

@description('Obtained from the networkHubParameters module.')
param privateDNSZones array

@description('The IP Plan for the environmentType. Obtained from the IP Plan module.')
param ipPlan object = {}

@description('Applications to whitelist. Must match a key in the IP Plan module')
param whitelistedApplications array = []

@description('Whitelisted IP ranges in CIDR notation.')
param whitelistedIpRanges object = {}

var ipAddressRangeVPN = ipPlan.VPN
var operationsSubscriptionID = (environmentType == 'PROD') ? 'x' : 'y'
var whitelistedApplicationObject = toObject(whitelistedApplications, appName => appName, appName => ipPlan[appName])
var whitelistObject = union(whitelistedApplicationObject, whitelistedIpRanges)


resource spokeRouteTable 'Microsoft.Network/routeTables@2022-11-01' = {
  name: 'RT-Spoke-${projectName}-${environmentType}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'Hub'
        properties: {
          addressPrefix: '10.0.0.0/8'
          nextHopType: 'VirtualNetworkGateway'
          hasBgpOverride: false
        }
        type: 'Microsoft.Network/routeTables/routes'
      }
      {
        name: 'VPN'
        properties: {
          addressPrefix: ipAddressRangeVPN
          nextHopType: 'VirtualNetworkGateway'
          hasBgpOverride: false
        }
        type: 'Microsoft.Network/routeTables/routes'
      }
    ]
  }
}

module virtualNetwork './spoke/virtualNetwork.bicep' = {
  name: 'vnet-${projectName}-${environmentType}'
  params: {
    tags: tags
    location: location
    environmentType: environmentType
    projectName: projectName
    ipAddressRange: ipAddressRange
    routeTableId: spokeRouteTable.id
  }
}

module networkSecurityGroupRules './spoke/networkSecurityGroups.bicep' = {
  name: 'nsgrules-${projectName}-${environmentType}'
  params: {
    ownAddressRange: ipAddressRange
    vpnAddressRange: ipAddressRangeVPN
    isolatedPrivateLinkNSGName: virtualNetwork.outputs.isolatedPrivateLinkNSGName
    sharedPrivateLinkNSGName: virtualNetwork.outputs.sharedPrivateLinkNSGName
    additionalWhitelistedApplications: whitelistObject
  }
}

module peeringHubSpoke './spoke/networkPeerings.bicep' = {
  name: 'peeringHubToSpoke-${projectName}-${environmentType}'
  params: {
    vnet1Name: virtualNetwork.outputs.virtualNetworksName
    vnet2Id: resourceId(operationsSubscriptionID, hubResourceGroupName, 'Microsoft.Network/virtualNetworks', hubVnetName) 
    peeringName: 'Hub-to-${projectName}'
    useRemoteVirtualGateway: true
  }
}

module peeringSpokeHub './spoke/networkPeerings.bicep' = {
  name: 'peeringSpokeToHub-${projectName}-${environmentType}'
  scope: resourceGroup(operationsSubscriptionID, hubResourceGroupName)
  params: {
    vnet1Name: hubVnetName
    vnet2Id: virtualNetwork.outputs.virtualNetworksId
    peeringName: '${projectName}-to-Hub'
    useRemoteVirtualGateway: false
  }
}

module privateDNSZoneLink './spoke/privateDNSZoneLinks.bicep' = {
  name: 'DNSLinks-${projectName}-${environmentType}'
  scope: resourceGroup(operationsSubscriptionID, hubResourceGroupName)
  params: {
    projectName: projectName
    VNetId: virtualNetwork.outputs.virtualNetworksId
    zoneList: privateDNSZones
  }  
}

output appServiceSubnetId string = virtualNetwork.outputs.appServiceSubnetId
output isolatedPrivateLinkSubnetId string = virtualNetwork.outputs.isolatedPrivateLinkSubnetId
output sharedPrivateLinkSubnetId string = virtualNetwork.outputs.sharedPrivateLinkSubnetId
output virtualNetworksName string = virtualNetwork.outputs.virtualNetworksName
output virtualNetworksId string = virtualNetwork.outputs.virtualNetworksId
