@description('Name of the SQL-server')
param databaseServerName string

@description('The virtualNetwork name.')
param virtualNetworkName string

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

var privateEndpointsName = 'PrivateLinkSubnet'
var privateDnsZonesName = 'privatelink.database.windows.net'


resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateDnsZonesName
  location: 'global'
  tags: tags
}

resource VNET 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: virtualNetworkName

  resource subnet 'subnets@2022-07-01' existing = {
    name: privateEndpointsName
  }
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = {
  name: databaseServerName
}

resource virtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: privateDnsZones
  name: 'link-to-${virtualNetworkName}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: VNET.id
    }
  }
}

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: privateEndpointsName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: VNET.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointsName
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }

  resource privateDnsZoneGroup 'privateDnsZoneGroups@2020-03-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-database-windows-net'
          properties: {
            privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', privateDnsZonesName)
          }
        }
      ]
    }
  }
}

resource privateDnsZones_Arecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: privateDnsZones
  name: databaseServerName
  properties: {
    ttl: 10
    aRecords: [
      {
        ipv4Address: '10.1.1.4'
      }
    ]
  }
}

resource Microsoft_Network_SOArecord 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  parent: privateDnsZones
  name: '@'
  properties: {
    ttl: 3600
    soaRecord: {
      email: 'azureprivatedns-host.microsoft.com'
      expireTime: 2419200
      host: 'azureprivatedns.net'
      minimumTtl: 10
      refreshTime: 3600
      retryTime: 300
      serialNumber: 1
    }
  }
}
