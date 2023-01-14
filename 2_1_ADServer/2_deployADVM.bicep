//Configure the base line infrastructure for the deployment
//This BICEP file relies on the MSRersourceModules folder which in turn is a git submodule of https://github.com/Azure/ResourceModules.git

//NOTES:
/*
  As part of best practice the deployment uses "EncryptionAtHost" by default for the VMs.  Depending on your subscription, 
  this may or may not have been registered as a azure feature.  If you run the script and get "feature is not enabled for this subscription"
  the feature is likley not enabled.  To resolve this, at the command line run:

  Get-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute"
  Check to see if it is registerd

  If it is not then run this:
  Register-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute"

  Check the status until it shows as registered with:
  Get-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute"
  
  Alternativly, set the EncryptionHost parameter to false below
*/

targetScope = 'subscription'

//Parameters
@allowed([
  'dev'
  'prod'
])
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@maxLength(4)
@description('Product Short Name e.g. QBX - no more than 4 characters')
param productShortName string = 'QBX'

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  Product: productShortName
}

//AD Identity Resource Group
@description ('The name of the Resource Group where identity and AD resources are deployed')
param RGID string = toUpper('${productShortName}-RG-identity-${localenv}')

//LAW Resource Group name
@description ('The name of the Log Analytics Workspace Resource Group')
param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

//Diagnostics
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

@description('Name of the boot diagnostic storage account')
param bootDiagStorageAccName string = toLower('${productShortName}stdiag${localenv}')

//AD Keyvault
@description('The name of the AD Key Vault')
param ADKeyVaultName string = toLower('${productShortName}-kv-ad-${localenv}')

//Identity VNET - subnet where the VM will create its NIC
@description('The id of the SNET where the AD server will be deployed')
param identityADSnetId string

//AD Server
@description('The name of the AD server VM (netbios)')
param VMADServerVMName string = toLower('${productShortName}ad1${localenv}')

@description('The size of the AD server VM')
param VMADServerVMSize string = 'Standard_B2s'

@description('Enable or disable encryption at host for the AD server VM - see notes at top of bicep file for more info (true/false)')
param encryptionAtHost bool = true

@description('The static IP address of the server')
param VMStaticIpAddress string = '10.245.8.20'

@description('The name of the AD server VM admin user')
param VMADAdminUserName string

//Domain settings
@description('The name of the domain to create on AdDS deployment') 
param domainName string = 'quberatron.com'

@description('The Name of storage account where the AD scripts are stored')
param scriptStorageName string

@description('The RG of storage account where the AD scripts are stored')
param scriptStorageRG string

@description('The path within the script storage account where the AD scripts are stored')
param scriptStoragePath string = '/scripts/CreateForest.ps1'

@description('Configure a shutdown time for the AD server (HHMM)')
param shutdownTime string = ''

//VARIABLES


//RESOURCES

//Pull in the identity resource group
resource IDRG 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: RGID
}

//Retrieve the CORE Log Analytics workspace
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LAWorkspaceName
  scope: resourceGroup(RGLAW)
}

//Create storage account for the boot diagnostics
module ADVMBootDiag '../MSResourceModules/modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'ADVMBootDiag'
  scope: IDRG
  params: {
    location: location
    tags: tags
    name: bootDiagStorageAccName
    allowBlobPublicAccess: false
    diagnosticLogsRetentionInDays: 7
    diagnosticWorkspaceId: LAWorkspace.id
    storageAccountSku: 'Standard_LRS'
  }
}

//Get the KeyVault
resource ADKeyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: ADKeyVaultName
  scope: IDRG
}

//Get the Script Storage Account
resource scriptStorage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: scriptStorageName
  scope: resourceGroup(scriptStorageRG)
}

//Create the AD virtual machine (configure as primary)
module ADVM1 '../MSResourceModules/modules/Microsoft.Compute/virtualMachines/deploy.bicep' = {
  name: 'ADVM1'
  scope: IDRG
  params: {
    location: location
    tags: tags
    vmSize: VMADServerVMSize
    adminUsername: VMADAdminUserName
    adminPassword:  ADKeyvault.getSecret('ADAdminPassword')
    name: VMADServerVMName
    encryptionAtHost: encryptionAtHost
    systemAssignedIdentity: true
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-Datacenter'
      version: 'latest'
    }
    osDisk: {
      name: 'osdisk'
      caching: 'ReadWrite'
      createOption: 'FromImage'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    nicConfigurations: [
      {
        deleteOption: 'Delete'
        //enablePublicIp: false
        enableAcceleratedNetworking: false
        ipConfigurations: [
          {
            name: VMADServerVMName
            subnetResourceId: identityADSnetId
            privateIPAllocationMethod: 'Static'
            privateIPAddress: VMStaticIpAddress
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]

    monitoringWorkspaceId: LAWorkspace.id

    diagnosticWorkspaceId: LAWorkspace.id
    nicdiagnosticMetricsToEnable: [
      'AllMetrics'
    ]

    bootDiagnostics: true
    bootDiagnosticStorageAccountName: ADVMBootDiag.outputs.name
  
    extensionAntiMalwareConfig: {
      enabled: true
      settings: {
        AntimalwareEnabled: 'true'
        RealtimeProtectionEnabled: 'true'
        ScheduledScanSettings: {
          day: '7'
          isEnabled: 'true'
          scanType: 'Quick'
          time: '120'
        }
      }
    }

    extensionMonitoringAgentConfig: {
      enabled: true
    }

    extensionNetworkWatcherAgentConfig: {
      enabled: true
    }

  }
}

//GRant the VM access to the scriptStorage blobs via an RG RBAC
module GrantRBACStorageBlobReader '../MSResourceModules/modules/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = {
  name: 'GrantRBACStorageBlobReader'
  scope: IDRG
  params: {
    principalId: ADVM1.outputs.systemAssignedPrincipalId
    roleDefinitionIdOrName: 'Storage Blob Data Reader'
    description: 'Grant read access to storage account blobs for the AD VM'
    resourceGroupName: IDRG.name
  }
}

//Deploy the ADDS build script and convert the VM into a fully operational AD server
module DeployADDS 'modules/deployADDS.bicep' = {
  name: 'DeployADDS'
  scope: IDRG
  params: {
    location: location
    tags: tags
    domainName: domainName
    vmName: ADVM1.outputs.name
    storageURI: '${scriptStorage.properties.primaryEndpoints.blob}${scriptStoragePath}'
  }
  dependsOn: [
    GrantRBACStorageBlobReader
  ]
}

//Configure AutoShutdown (if required)
module vmShutdown './modules/configureShutdown.bicep' = if (shutdownTime != '') {
  name: 'vmShutdown'
  scope: IDRG
  params: {
    location: location
    tags: tags
    vmName: ADVM1.outputs.name
    shutdownTime: shutdownTime
  }
}


//OUTPUTS
output storageURI string = '${scriptStorage.properties.primaryEndpoints.blob}${scriptStoragePath}'
output VMADServerVMName string = ADVM1.outputs.name
output VMADServerVMRG string = ADVM1.outputs.resourceGroupName
