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

@description('Route Table for the subnets')
param routeTableId string = ''

var virtualNetworkName = 'VNET-${projectName}-${environmentType}'

resource isolatedPrivateLinkNSG 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'NSG-${projectName}-IsolatedPrivateLink-${environmentType}'
  location: location
  tags: tags
}

resource sharedPrivateLinkNSG 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'NSG-${projectName}-SharedPrivateLink-${environmentType}'
  location: location
  tags: tags
}

resource virtualNetworks 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        ipAddressRange
      ]
    }
    subnets: [
      {
        name: 'SharedPrivateLinkSubnet'
        properties: {
          addressPrefix: cidrSubnet(ipAddressRange, 26, 1)
          delegations: []
          privateEndpointNetworkPolicies: 'NetworkSecurityGroupEnabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: routeTableId == '' ? null : {
            id: routeTableId
          }
          networkSecurityGroup: {
            id: sharedPrivateLinkNSG.id
          }
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'IsolatedPrivateLinkSubnet'
        properties: {
          addressPrefix: cidrSubnet(ipAddressRange, 26, 2)
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: routeTableId == '' ? null : {
            id: routeTableId
          }
          networkSecurityGroup: {
            id: isolatedPrivateLinkNSG.id
          }
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'AppSvcSubnet'
        properties: {
          addressPrefix: cidrSubnet(ipAddressRange, 26, 3)
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          // Unknown if this is needed for internal communications
          /*routeTable: routeTableId == '' ? null : {
            id: routeTableId
          }*/ 
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    enableDdosProtection: false
  }
}

resource isolatedPrivateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  parent: virtualNetworks
  name: 'IsolatedPrivateLinkSubnet'
}

resource sharedPrivateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  parent: virtualNetworks
  name: 'SharedPrivateLinkSubnet'
}

resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  parent: virtualNetworks
  name: 'AppSvcSubnet'
}

output appServiceSubnetId string = appServiceSubnet.id
output isolatedPrivateLinkNSGName string = isolatedPrivateLinkNSG.name
output isolatedPrivateLinkSubnetId string = isolatedPrivateLinkSubnet.id
output sharedPrivateLinkNSGName string = sharedPrivateLinkNSG.name
output sharedPrivateLinkSubnetId string = sharedPrivateLinkSubnet.id
output virtualNetworksName string = virtualNetworks.name
output virtualNetworksId string = virtualNetworks.id
