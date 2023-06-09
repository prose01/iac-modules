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

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object


var storageAccountName = toLower('sto${projectName}${substring(uniqueString(resourceGroup().id), 0, 1)}${environmentType}')
var storageAccountSkuName = (environmentType == 'PROD') ? 'Standard_GRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
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

output name string = storageAccount.name
