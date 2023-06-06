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

var virtualNetworkName = 'VN-${projectName}-${environmentType}'

resource virtualNetworks 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'PrivateLinkSubnet'
        properties: {
          addressPrefix: '10.1.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'AppSvcSubnet'
        properties: {
          addressPrefix: '10.1.2.0/24'
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
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }

  resource subnet1 'subnets' existing = {
    name: 'PrivateLinkSubnet'
  }
}

output virtualNetworksName string = virtualNetworks.name
output virtualNetworksId string = virtualNetworks.id
output subnetId0 string = virtualNetworks.properties.subnets[0].id
output subnetId1 string = virtualNetworks.properties.subnets[1].id
