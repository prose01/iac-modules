@description('The name of the Network Security Group attached to the IsolatedPrivateLink subnet.')
param isolatedPrivateLinkNSGName string
@description('The name of the Network Security Group attached to the SharedPrivateLink subnet.')
param sharedPrivateLinkNSGName string
@description('IP address range for the spoke VNET.')
param ownAddressRange string
@description('IP address range for VPN connections.')
param vpnAddressRange string
@description('Additional CIDR blocks that should be whitelisted. The key should be an application name or similar identifer.')
param additionalWhitelistedApplications object

var applications = items(additionalWhitelistedApplications)

resource isolatedPrivateLinkNSG 'Microsoft.Network/networkSecurityGroups@2022-11-01' existing = {
  name: isolatedPrivateLinkNSGName
}

resource sharedPrivateLinkNSG 'Microsoft.Network/networkSecurityGroups@2022-11-01' existing = {
  name: sharedPrivateLinkNSGName
}

resource allowSelfIsolated 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'AllowSelf'
  parent: isolatedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 100
    access: 'Allow'
    protocol: '*'
    sourceAddressPrefix: ownAddressRange
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource allowVPNTrafficIsolated 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'AllowVPNTraffic'
  parent: isolatedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 101
    access: 'Allow'
    protocol: '*'
    sourceAddressPrefix: vpnAddressRange
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource blockInternalTrafficIsolated 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'BlockInternalTraffic'
  parent: isolatedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 1000
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '10.0.0.0/8'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource allowSelfShared 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'AllowSelf'
  parent: sharedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 100
    access: 'Allow'
    protocol: '*'
    sourceAddressPrefix: ownAddressRange
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource allowVPNTrafficShared 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'AllowVPNTraffic'
  parent: sharedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 101
    access: 'Allow'
    protocol: '*'
    sourceAddressPrefix: vpnAddressRange
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource allowOtherApps 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = [ for i in range(0, length(additionalWhitelistedApplications)): {
  name: 'AllowTrafficFor${applications[i].key}'
  parent: sharedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 102 + i
    access: 'Allow'
    protocol: '*'
    sourceAddressPrefix: applications[i].value
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}]

resource blockInternalTrafficShared 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'BlockInternalTraffic'
  parent: sharedPrivateLinkNSG
  properties: {
    direction: 'Inbound'
    priority: 1000
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '10.0.0.0/8'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}
