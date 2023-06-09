@description('Name of the Function App Service.')
param projectName string

@description('The name of the environment. This must be DEV, TEST, or PROD.')
@allowed([
  'DEV'
  'TEST'
  'PROD'
])
param environmentType string

@description('ID of the App Service Plan')
param appServicePlanID string

@description('Linux App Framework and version')
@allowed([
  'DOTNET|6.0'
  'NODE|16-lts'
])
param linuxFxVersion string = 'DOTNET|6.0'

@description('Additional app settings for Function App Service')
param additionalFunctionAppSettings object = {}

@description('Additional connectionStrings settings for Function App Service')
param additionalFunctionConnectionStrings object = {}

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'dotnet-isolated'
])
param runtime string = 'node'

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

var functionAppServiceAppName = 'FA-${projectName}-${environmentType}'

var operationsSubscriptionID = (environmentType == 'PROD') ? 'f90f8a3d-20be-47ae-9441-12b4f6c208d4' : 'd4b1b72a-4757-46bf-b21a-bc06d047bf81'
var resourceGroupName = (environmentType == 'PROD') ? 'rg-logs-prod' : 'rg-logs-dev'
var logAnalyticsWorkspace = (environmentType == 'PROD') ? 'LAW-LRUD-PROD' : 'LAW-LRUD-DEV'
var retentionInDays = (environmentType == 'PROD') ? 7 : 1


// module storageAccount './storageAccount.bicep' = {
//   name: 'storageAccount'
//   params: {
//     projectName: '${projectName}fa'
//     environmentType: environmentType
//     location: location
//     tags: tags
//   }
// }

var storageAccountName = toLower('sto${projectName}${substring(uniqueString(resourceGroup().id), 0, 1)}fa${environmentType}')
var storageAccountSkuName = (environmentType == 'PROD') ? 'Standard_GRS' : 'Standard_LRS'

// We need to make our own storage from functionApp as we need AccountKey secrets
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

module appInsights './appInsights.bicep' = {
  name: 'appinsights-${functionAppServiceAppName}'
  params: {
    projectName: projectName
    environmentType: environmentType
    WorkspaceResourceId: logAnalytics.id
    location: location
    tags: tags
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppServiceAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlanID
    siteConfig: {
      ftpsState: 'FtpsOnly'
      netFrameworkVersion: contains(linuxFxVersion,'DOTNET') ? 'v6.0' : null
      linuxFxVersion: linuxFxVersion
      http20Enabled: true
      minTlsVersion: '1.2'
      use32BitWorkerProcess: false
      httpLoggingEnabled: true
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    storageAccount
  ]
  tags: tags
}

var appSettingsBase = {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.outputs.instrumentationKey
  AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
  WEBSITE_CONTENTSHARE: toLower(functionAppServiceAppName)
  FUNCTIONS_EXTENSION_VERSION: '~4'
  FUNCTIONS_WORKER_RUNTIME: runtime 
  WEBSITES_ENABLE_APP_SERVICE_STORAGE: true
  WEBSITE_HTTPLOGGING_RETENTION_DAYS: retentionInDays
}

resource siteconfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: union(appSettingsBase, additionalFunctionAppSettings)
}

resource connectionstrings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'connectionstrings'
  properties: additionalFunctionConnectionStrings
}

resource logconfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'logs'
  properties: {    
  httpLogs: {
      fileSystem: {
        enabled: true
        retentionInDays: retentionInDays
        retentionInMb: 35
      }
    }
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: logAnalyticsWorkspace
  scope: resourceGroup(operationsSubscriptionID, resourceGroupName)
}

resource setting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Diagnostic Logs'
  scope: functionApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output functionAppIdentityId string = functionApp.identity.principalId
