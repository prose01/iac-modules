@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'PROD'
  'NONPROD'
])
param environmentType string

@description('Name of the project.')
param projectName string

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

@description('Obtained from the networkHubParameters module.')
param virtualNetworkName string

@description('Obtained from the networkHubParameters module.')
param privateDNSZoneList array

@description('Obtained from the networkIpPlan module.')
param ipPlan object

@description('The name of the operations key vault.')
param keyVaultName string

@description('The name of the resource group containing the operations key vault.')
param keyVaultResourceGroupName string

@description('The name of the subscription containing the operations key vault.')
param keyVaultSubscriptionId string

@description('The application id for the VPN audience in Azure Active Directory.')
param vpnApplicationId string

@description('List of valid root certificate names.')
param rootCertificateNames array

@description('Amount of root certificates. Must match the number of items in rootCertificateNames.')
@allowed([
  1
  2
])
param rootCertificateAmount int

@description('List of revoked client certificate SHA1 thumbprints.')
param revokedCertificateThumbprints array

var nameSuffix = 'Hub-${environmentType}'
var ipAddressRangeVNet = ipPlan.Hub
var ipAddressRangeVPN = ipPlan.VPN
var gatewaySubnetCIDR = cidrSubnet(ipAddressRangeVNet, 26, 3)
var generalSubnetCIDR = cidrSubnet(ipAddressRangeVNet, 26, 1)
var dnsServerIp = cidrHost(generalSubnetCIDR, 3)
var azureActiveDirectoryTenantId = 'x'
var rootCertificateOutput0 = rootCertificate0.outputs.certificate
var rootCertificateOutput1 = rootCertificateAmount == 2 ? rootCertificate1.outputs.certificate : ''

var rootCertificateObjects = map(range(0,rootCertificateAmount), idx => {
  name: 'Cert${idx}'
  properties: {
    publicCertData: idx == 0 ? rootCertificateOutput0 : rootCertificateOutput1
  }
}) 

var revokedCertificateThumbprintObjects = map(range(0, length(revokedCertificateThumbprints)), idx => {
    name: 'RevokedCert${idx}'
    properties: {
      thumbprint: revokedCertificateThumbprints[idx]
    }
  }
)

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultSubscriptionId, keyVaultResourceGroupName)
}

resource hubNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        ipAddressRangeVNet
      ]
    }
    dhcpOptions: {
      dnsServers: [dnsServerIp]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: generalSubnetCIDR
          serviceEndpoints: []
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetCIDR
          serviceEndpoints: []
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    enableDdosProtection: false
  }
}

module privateDNSZones './hub/privateDNSZone.bicep' = {
  name: 'privateDNSZones'
  params: {
    environmentType: environmentType
    tags: tags
    privateDNSZones: privateDNSZoneList
  }
}

resource vpnPublicIp1 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'IP-VPN-${nameSuffix}1'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource vpnPublicIp2 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'IP-VPN-${nameSuffix}2'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource vpnP2SIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'IP-VPN-P2S-${nameSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  parent: hubNetwork
  name: 'GatewaySubnet'
}

module rootCertificate0 './hub/publicCertificate.bicep' = {
  name: 'rootCertificate0'
  params: {
    location: location
    tags: tags
    certificate: keyVault.getSecret(rootCertificateNames[0])
    certificateName: rootCertificateNames[0]
  }
}

module rootCertificate1 './hub/publicCertificate.bicep' = if (rootCertificateAmount == 2) {
  name: 'rootCertificate1'
  params: {
    location: location
    tags: tags
    certificate: keyVault.getSecret(rootCertificateNames[1])
    certificateName: rootCertificateNames[1]
  }
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2022-11-01' = {
  name: 'VPN-${nameSuffix}'
  location: location
  tags: tags

  properties: {
    enablePrivateIpAddress: true
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vpnPublicIp1.id
          }
          subnet: {
            id: gatewaySubnet.id
          }
        }
      }
      {
        name: 'activeActive'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vpnPublicIp2.id
          }
          subnet: {
            id: gatewaySubnet.id
          }
        }
      }
      {
        name: 'IP-VPN-P2S'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vpnP2SIP.id
          }
          subnet: {
            id: gatewaySubnet.id
          }
        }
      }
    ]
    natRules: []
    virtualNetworkGatewayPolicyGroups: []
    enableBgpRouteTranslationForNat: false
    disableIPSecReplayProtection: false
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: true
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          ipAddressRangeVPN
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'AAD'
        'Certificate'
      ]
      aadAudience: vpnApplicationId
      aadIssuer: 'https://sts.windows.net/${azureActiveDirectoryTenantId}/'
      aadTenant: 'https://login.microsoftonline.com/${azureActiveDirectoryTenantId}/'
      vpnClientRootCertificates: rootCertificateObjects
      vpnClientRevokedCertificates: revokedCertificateThumbprintObjects
      vngClientConnectionConfigurations: []
      radiusServers: []
      vpnClientIpsecPolicies: []
    }
    customRoutes: {
      addressPrefixes: []
    }
    vpnGatewayGeneration: 'Generation1'
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false

  }
}

module dnsForwarder './hub/dnsForwarder.bicep' = {
  name: 'dnsForwarder'
  params:{
    tags: tags
    location: location
    environmentType: environmentType
    projectName: '${projectName}-DNSForwarder'
    dnsServerIp: dnsServerIp
    sshPublicKey: keyVault.getSecret('${projectName}-${environmentType}-dnsForwarder-ssh-public-key')
    vnetName: hubNetwork.name
    vpnAddressPrefix: ipAddressRangeVPN
  }
}

output vpnGatewayName string = vpnGateway.name
output vpnGatewayId string = vpnGateway.id
