@description('The name of the VNET')
param projectName string
@description('The resource id of the VNET')
param VNetId string
@description('A list of zones to link to the VNET')
param zoneList array

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [ for i in range(0, length(zoneList)): {
  name: zoneList[i]
}]

resource privateDNSZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [ for i in range(0, length(zoneList)): {
  name: '${projectName}-${zoneList[i]}'
  parent: privateDNSZone[i]
  location: 'global'
  properties: {
    virtualNetwork: {
      id: VNetId
    }
    registrationEnabled: false
  }
}]
