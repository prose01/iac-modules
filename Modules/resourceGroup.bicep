targetScope='subscription'

@description('Name of ResourceGroup.')
param projectName string
@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'DEV'
  'TEST'
  'PROD'
])
param environmentType string
@description('The Azure region into which the resources should be deployed.')
param location string = 'westeuro'
@description('Tags.')
param tags object


var resourceGroupName  = 'RG-${projectName}-${environmentType}'

resource newRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}
