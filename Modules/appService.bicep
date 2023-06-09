@description('Name of the App Service.')
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
  'DOTNETCORE|7.0'
  'NODE|18-lts'
])
param linuxFxVersion string = 'DOTNETCORE|7.0'

@description('App command line to launch.')
param appCommandLine string = ''

@description('Turn Affinity Cookie on-off.')
param clientAffinityEnabled bool = false

@description('Virtual Network Subnet Id.')
param virtualNetworkSubnetId string = ''

@description('Additional app settings for App Service')
param additionalAppSettings object = {}

@description('Additional connectionStrings settings for App Service')
param additionalConnectionStrings object = {}

@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

var appServiceAppName = 'WEB-${projectName}-${environmentType}'
// var operationsSubscriptionID = (environmentType == 'PROD') ? 'f90f8a3d-20be-47ae-9441-12b4f6c208d4' : 'd4b1b72a-4757-46bf-b21a-bc06d047bf81'
// var resourceGroupName = (environmentType == 'PROD') ? 'rg-logs-prod' : 'rg-logs-dev'
// var logAnalyticsWorkspace = (environmentType == 'PROD') ? 'LAW-LRUD-PROD' : 'LAW-LRUD-DEV'
var retentionInDays = (environmentType == 'PROD') ? 7 : 1


module appInsights './appInsights.bicep' = {
  name: 'appinsights-${appServiceAppName}'
  params: {
    projectName: projectName
    environmentType: environmentType
    // WorkspaceResourceId: logAnalytics.id
    location: location
    tags: tags
  }
}

resource appServiceApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlanID
    siteConfig:{
      alwaysOn: true
      ftpsState: 'FtpsOnly'
      netFrameworkVersion: contains(linuxFxVersion,'DOTNETCORE') ? 'v7.0' : null
      linuxFxVersion: linuxFxVersion
      appCommandLine: appCommandLine
      http20Enabled: true
      minTlsVersion: '1.2'
      use32BitWorkerProcess: false
      httpLoggingEnabled: true
      vnetRouteAllEnabled: true
    }
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: true
    virtualNetworkSubnetId: empty(virtualNetworkSubnetId) ? null : virtualNetworkSubnetId
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
}

var appSettingsBase = {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.outputs.instrumentationKey
  WEBSITE_HTTPLOGGING_RETENTION_DAYS: retentionInDays
}

resource siteconfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appServiceApp
  name: 'appsettings'
  properties: union(appSettingsBase, additionalAppSettings)
}

resource connectionstrings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appServiceApp
  name: 'connectionstrings'
  properties: additionalConnectionStrings
}

resource logconfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appServiceApp
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

// resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
//   name: logAnalyticsWorkspace
//   scope: resourceGroup(operationsSubscriptionID, resourceGroupName)
// }

// resource setting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'Diagnostic Logs'
//   scope: appServiceApp
//   properties: {
//     workspaceId: logAnalytics.id
//     logs: [
//       {
//         category: 'AppServiceAntivirusScanAuditLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServiceHTTPLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServiceConsoleLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServiceAppLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServiceFileAuditLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServiceAuditLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServiceIPSecAuditLogs'
//         enabled: true
//       }
//       {
//         category: 'AppServicePlatformLogs'
//         enabled: true
//       }
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }


output appServiceAppHostName string = appServiceApp.properties.defaultHostName
output appServiceIdentityId string = appServiceApp.identity.principalId
output appServiceAppName string = appServiceApp.name

