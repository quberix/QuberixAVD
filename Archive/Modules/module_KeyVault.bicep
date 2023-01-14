//Deploy a keyvault and associated diagnostics
@description('Tags for the deployed resources')
param tags object

@description('Geographic Location of the Resources.')
param location string = resourceGroup().location

@description('ID of the Log Analytics service to send debug info to.')
param lawID string

@description('Name of the keyvault')
param keyVaultName string

@description('Keyvault SKU - default: standard')
@allowed([
  'standard'
  'premium'
])
param keyVaultSku string = 'standard'

//Access policies
@description('Array describing the access policy to apply')
param accessPolicy array = []

// Note: Access policy should be in form:
// [
//   {
//     objectId: objectId
//     tenantId: tenantId
//     permissions: {
//       keys: [keysPermissions]
//       secrets: [secretsPermissions]
//       certificates: [certificatesPermissions]
//     }
//   }
// ]

@description('List of IP addresses to permit')
param networkIPPermit array = []

@description('List of virtual network IDs to permit')
param networkIDsPermit array = []

//Keyvault configuration
@description('Enable keyvault for deployment')
param enableDeployment bool = false

@description('Enable keyvault for template deployment')
param enableTemplateDeployment bool = false

@description('Enable keyvault for disk encryption')
param enableDiskEncryption bool = false

@description('Enable RBAC based authorisation')
param enableRbacAuthorisation bool = true

@description('Enable Purge Protection')
param enablePurgeProtection bool = false

@description('Enable Soft Delete')
param enablesoftDelete bool = false

//Keyvault private endpoint options
@description('Create a private endpoint')
param deployPrivateEndpoint bool = false

//VARIABLES
var publicNetworkAccess = deployPrivateEndpoint ? 'disabled' : 'enabled'

//RESOURCES
//Build the keyvault
resource Vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: enableDeployment
    enabledForTemplateDeployment: enableTemplateDeployment
    enabledForDiskEncryption: enableDiskEncryption
    enablePurgeProtection: enablePurgeProtection == true ? true : json('null')
    enableRbacAuthorization: enableRbacAuthorisation
    enableSoftDelete: enablesoftDelete
    tenantId: tenant().tenantId
    accessPolicies: accessPolicy
    publicNetworkAccess: publicNetworkAccess
    sku: {
      name: keyVaultSku
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: networkIPPermit
      virtualNetworkRules: networkIDsPermit
    }
  }
}

//If specified attach the LAW
resource VaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (lawID != '') {
  scope: Vault
  name: '${keyVaultName}-kv-diagnostics'
  properties: {
    workspaceId: lawID
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 14
          enabled: true
        }
      }
    ]
  }
}
