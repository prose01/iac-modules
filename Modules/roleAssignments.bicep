targetScope = 'resourceGroup'

@description('The role definition ID.')
@allowed([
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
])
param roleDefinitionIds array

@description('The principal ID that is owner of the subcription.')
param principalId string

@description('The principal type of the assigned principal ID.')
param principalType string


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(resourceGroup().id, roleDefinitionId, principalId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}]
