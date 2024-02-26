@description('Name of the S2S Connection.')
param projectName string

@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'PROD'
  'NONPROD'
])
param environmentType string

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

@description('The name of the Azure Virtual Network Gateway.')
param vpnGatewayName string

@description('The remote gateway IP address.')
param remoteGatewayAddress string

@description('The remote network IP address ranges.')
param remoteNetworkAddressPrefixes array

@description('The pre-shared key used for authentication')
@secure()
param preSharedKey string

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2022-11-01' existing = {
  name: vpnGatewayName
}

resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2022-11-01' = {
  name: 'LGW-${projectName}-${environmentType}'
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: remoteGatewayAddress
    localNetworkAddressSpace: {
      addressPrefixes: remoteNetworkAddressPrefixes
    }
  }
}

resource s2sConnection 'Microsoft.Network/connections@2022-11-01' = {
  name: 'S2S-${projectName}-${environmentType}'
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    localNetworkGateway2: {
      id: localNetworkGateway.id
      properties: localNetworkGateway.properties
    }
    virtualNetworkGateway1: {
      id: vpnGateway.id
      properties: vpnGateway.properties
      
    }
    sharedKey: preSharedKey
    connectionProtocol: 'IKEv2'
    connectionMode:'ResponderOnly'
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 28800
        saDataSizeKilobytes: 0
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        pfsGroup: 'None'
      }
    ]
  }
}
