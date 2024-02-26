@description('Name of the Storage Account.')
@minLength(3)
@maxLength(18)
param projectName string

@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'DEV'
  'TEST'
  'PROD'
])
param environmentType string

@description('The container names.')
param containerNames array = []

// @description('Specifies CORS rules for the Blob service. You can include up to five CorsRule elements in the request.')
// param corsRules array = [{}]

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object


var storageAccountName = toLower('sto${projectName}${substring(uniqueString(resourceGroup().id), 0, 1)}${environmentType}')
var storageAccountSkuName = (environmentType == 'PROD') ? 'Standard_GRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: toLower(storageAccountName)
  location: location
  sku: {
    name: storageAccountSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
  tags: tags
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01'= {
  name: 'default'
  parent: storageAccount
  properties: {
    changeFeed: {
      enabled: false
    }
    restorePolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    } 
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = [for containerName in containerNames : {
  name: toLower(containerName)
  parent: blobServices
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

output name string = storageAccount.name
