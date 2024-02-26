@description('The name of the environment. This must be DEV, TEST, NONPROD, or PROD.')
@allowed([
  'DEV'
  'TEST'
  'NONPROD'
  'PROD'
])
param environmentType string

var hubEnvironmentSuffix = environmentType == 'PROD' ? environmentType : 'NONPROD'
var nameSuffix = 'Hub-${hubEnvironmentSuffix}'

output hubResourceGroupName string = 'RG-NetworkHub-${hubEnvironmentSuffix}'
output operationsKeyvaultResourceGroupName string = environmentType == 'PROD' ? 'RG-Operations-PROD' : 'RG-Operations-DEV'
output operationsKeyvaultName string = environmentType == 'PROD' ? 'KV-OPERATIONS-PROD' : 'KV-OPERATIONS-DEV'
output operationsSubscriptionID string = environmentType == 'PROD' ? 'x' : 'y'
output privateDNSZones array = ['privatelink.azurewebsites.net', 'privatelink${environment().suffixes.sqlServerHostname}']
output virtualNetworkName string = 'VNET-${nameSuffix}'
output vpnApplicationClientId string = environmentType == 'PROD' ? 'x' : 'y'
