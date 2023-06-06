@description('Name of the App Service Plan.')
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

@description('The SKU of App Service Plan.')
param appServicePlanSkuName string
@description('The number of App Service plan instances.')
@minValue(1)
@maxValue(10)
param appServicePlanInstanceCount int = 1

@allowed([
  'Win'
  'Linux'
])
@description('Select the OS type to deploy.')
param appServicePlanPlatform string = 'Linux'

@description('Tags.')
param tags object

var appServicePlanName = 'ASP-${projectName}-${appServicePlanPlatform}-${environmentType}'


resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: ((appServicePlanPlatform == 'Linux') ? true : false)
  }
  sku: {
    name: appServicePlanSkuName
    capacity: appServicePlanInstanceCount
  }
  kind: ((appServicePlanPlatform == 'Linux') ? 'linux' : 'windows')
  tags: tags
}

output appServicePlanID string = appServicePlan.id
