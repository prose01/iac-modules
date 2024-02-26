@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'PROD'
  'NONPROD'
])
param environmentType string

@description('Tags.')
param tags object

@description('A list of private DNS zones to create.')
param privateDNSZones array

var nameSuffix = 'Hub-${environmentType}'
var virtualNetworkName = 'VNET-${nameSuffix}'

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for i in range(0,length(privateDNSZones)): {
  name: privateDNSZones[i]
  location: 'global'
  tags: tags
}]

resource privateDnsZoneAssociation 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for i in range(0,length(privateDNSZones)): {
  name: nameSuffix
  location: 'global'
  tags: tags
  parent: privateDNSZone[i]
  properties: {
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', virtualNetworkName)
    }
    registrationEnabled: false
  }
}]
