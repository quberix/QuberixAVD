//Takes a list ob secret objects and adds them to the keyvault

param tags object
param vaultName string
param vaultSecretName string
param vaultContentType string = 'string'

@secure()
param vaultSecretValue string

resource Vault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: vaultName
}

resource vaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: vaultSecretName
  tags: tags
  parent: Vault
  properties: {
    attributes: {
      enabled: true
    }
    contentType: vaultContentType
    value: vaultSecretValue
  }
}
