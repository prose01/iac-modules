@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location
@description('Name of Storage Account.')
@minLength(5)
@maxLength(24)
param storageAccountName string
@description('The SKU of Storage Account.')
param storageAccountSkuName string
@description('Tags.')
param tags object

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
