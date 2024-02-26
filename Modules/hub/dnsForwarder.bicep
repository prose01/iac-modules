@description('Name of the Virtual Machine.')
param projectName string

@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'PROD'
  'NONPROD'
])
param environmentType string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

@description('Hub VNET name.')
param vnetName string

@description('CIDR block for VPN.')
param vpnAddressPrefix string

@description('Private IP of the DNS server.')
param dnsServerIp string

@description('Admin username.')
param adminUsername string = 'azureuser'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param sshPublicKey string

@description('Virtual machine size')
param vmSize string = 'Standard_B1s'

var forwardIP = '168.63.129.16' // Azure DNS
var ubuntuOffer = '0001-com-ubuntu-server-jammy'
var ubuntuOSVersion = '22_04-lts-gen2'
var nsgName = 'NSG-${projectName}-${environmentType}'
var subNetName = 'General'
var storType = 'Standard_LRS'
var nicName = 'NIC-${projectName}-${environmentType}'
var scriptUrl = '${storageAccount.properties.primaryEndpoints.blob}scripts/forwarderSetup.sh'

resource storageAccount 'Microsoft.Storage/StorageAccounts@2019-06-01' = {
  name: toLower('stohubdnsproxy${environmentType}')
  location: location
  tags: tags
  sku: {
    name: storType
  }
  kind: 'StorageV2'

  resource blobService 'blobServices' = {
    name: 'default'

    resource container 'containers' = {
      name: 'scripts'
      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'DS-upload-blob'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.48.1'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccount.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: loadTextContent('forwarderSetup.sh')
      }
    ]
    scriptContent: 'echo "$CONTENT" > forwarderSetup.sh && az storage blob upload -f forwarderSetup.sh -c scripts -n forwarderSetup.sh --overwrite'
  }
}

resource sshKey 'Microsoft.Compute/sshPublicKeys@2023-03-01' = {
  name: 'SSH-${projectName}-${environmentType}'
  location: location
  tags: tags
  properties: {
    publicKey: sshPublicKey
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow_ssh_from_vnet'
        properties: {
          description: 'The only thing allowed is SSH'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.0.0/8'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'allow_ssh_from_vpn'
        properties: {
          description: 'The only thing allowed is SSH'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: vpnAddressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'allow_storage'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Storage'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 111
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          primary: true
          privateIPAddress: dnsServerIp
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subNetName)
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'VM-${projectName}-${environmentType}'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: projectName
      adminUsername: adminUsername
      adminPassword: sshKey.properties.publicKey
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKey.properties.publicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: ubuntuOffer
        sku: ubuntuOSVersion
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

resource setupdnsfirewall 'Microsoft.Compute/virtualMachines/extensions@2019-12-01' = {
  parent: virtualMachine
  name: 'setupdnsfirewall'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'resolvectl dns eth0 ${forwardIP}; wget ${scriptUrl}; chmod +x forwarderSetup; sh ./forwarderSetup.sh ${forwardIP} ${vpnAddressPrefix}; resolvectl revert eth0'
    }
  }
  dependsOn: [deploymentScript]
}

