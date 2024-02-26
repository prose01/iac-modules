@description('The Azure region into which the resources should be deployed.')
param location string = resourceGroup().location

@description('Tags.')
param tags object

@description('Valid root certificate name data')
@secure()
param certificate string

@description('Certificate name (used for resource naming only).')
param certificateName string

resource certificateSecrets 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'DS-PublicCert-${certificateName}'
  location: location
  tags: tags
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.48.1'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'CERT_SECRET'
        secureValue: certificate
      }
    ]
    scriptContent: '''
echo "$CERT_SECRET" | base64 -d > combined.pfx
CERT_DATA="$(openssl x509 -in combined.pfx -inform der -outform der | base64 -w0)"
echo "{\"cert\":\"$CERT_DATA\"}" > $AZ_SCRIPTS_OUTPUT_PATH
'''
  }
}

output certificate string = certificateSecrets.properties.outputs.cert
