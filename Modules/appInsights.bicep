@description('Name of the Application Insights.')
param projectName string

@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'DEV'
  'TEST'
  'PROD'
])

param environmentType string
// @description('WorkspaceResourceId.')
// param WorkspaceResourceId string
@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location
@description('Tags.')
param tags object


var applicationInsightsName = 'AI-${projectName}-${environmentType}'

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    // WorkspaceResourceId: WorkspaceResourceId
  }
  tags: tags
}
output instrumentationKey string = appInsights.properties.InstrumentationKey
