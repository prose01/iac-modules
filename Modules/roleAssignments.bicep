targetScope = 'resourceGroup'

@description('The role definition ID.')
@allowed([
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader, used to allow LRUD-Developers group to read Resource Group 
  '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' // Azure Service Bus Data Receiver
  '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39' // Azure Service Bus Data Sender
])
param roleDefinitionIds array

@description('The principal ID that is owner of the subcription.')
param principalId string

@description('The principal type of the assigned principal ID.')
param principalType string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  // name: guid('LRUD-Developers', 'reader') Microsoft cannot just use any name so they need a guid ;)
  name: guid(resourceGroup().id, roleDefinitionId, principalId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    // principalId: 'cce952a0-10bb-432f-8a13-07b20a0dd412' This is LRIADMPRO-IaC-Bicep-06d64dc5-ea33-4506-bb93-b508a4ef2b0d who is owner on subcription
    principalId: principalId
    principalType: principalType
  }
}]
