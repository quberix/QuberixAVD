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

//LAW workspace
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

//Script Storage
@description('Storage account to store the AD scripts')
param ScriptStorageAccName string = toLower('${productShortName}stscripts${localenv}')

@description('The name of the container for scripts iun the storage account')
param scriptContainerName string = 'scripts'

//AD Keyvault
@description('The name of the AD Key Vault')
param ADKeyVaultName string = toLower('${productShortName}-kv-ad-${localenv}')

@description('The password of the AD server VM admin user')
@secure()
param VMADAdminPassword string

@description('The password for the Safe Mode domain administrator account')
@secure()
param domainSafeModePass string

@description('The name of the AD server VM admin user')
param VMADAdminUserName string


//AD Vnet
@description('The name of the Identity Virtual Network')
param IDVnetName string = toLower('${productShortName}-identity-vnet-${localenv}')

@description('The CIDR of the Identity Virtual Network')
param IDVnetCIDR string = '10.245.8.0/24'

@description('The Name of the AD server subnet in the Identity Virtual Network')
param IDSnetADName string = toLower('${productShortName}-ad-snet-${localenv}')

@description('The CIDR of the AD server subnet in the Identity Virtual Network')
param IDSnetADCIDR string = '10.245.8.0/27'

@description('The name of the NSG for the AD subnet NSG')
param IDNSGADName string = toLower('${productShortName}-identity-ad-nsg-${localenv}')

//Boundary Vnet
@description('The name of the Resource Group where boundary resources are deployed')
param RGBoundary string = toUpper('${productShortName}-RG-Boundary-${localenv}')

//Boundary Vnet (required for peering)
@description('The name of the Boundary Virtual Network (deployed in 2_0)')
param BoundaryVnetName string = toLower('${productShortName}-boundary-vnet-${localenv}')

//Private DNS Zones to set up
@description('The private DNS zones to set up')
param privateDNSZones array = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
]

@description('The IP address of where the build script is running from')
param localScriptIPAddress string

//VARIABLES


//RESOURCES

//Create the identity resource group
resource IDRG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGID
  location: location
  tags: tags
}


//Retrieve the CORE Log Analytics workspace
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LAWorkspaceName
  scope: resourceGroup(RGLAW)
}

//Deploy the Identity virtual network components so we can build the AD server
//Create the Identity snet AD NSG and required rules
module IdentityADNSG '../MSResourceModules/modules/Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  name: 'IdentityADNSG'
  scope: IDRG
  params: {
    location: location
    name: IDNSGADName
    tags: tags
    // securityRules: [
    //   //Inbound
    //   {
    //     name: 'AllowUDPInbound'
    //     properties: {
    //       direction: 'Inbound'
    //       priority: 1000
    //       protocol: 'Udp'
    //       sourceAddressPrefix: 'VirtualNetwork'
    //       sourcePortRange: '*'
    //       destinationAddressPrefix: IDSnetADCIDR
    //       destinationPortRanges: [
    //         '138' //Replication (e.g. group policy)
    //       ]
    //       access: 'Allow'
    //     }
    //   }
    //   {
    //     name: 'AllowTCPInbound'
    //     properties: {
    //       direction: 'Inbound'
    //       priority: 1001
    //       protocol: 'Tcp'
    //       sourceAddressPrefix: 'VirtualNetwork'
    //       sourcePortRange: '*'
    //       destinationAddressPrefix: IDSnetADCIDR
    //       destinationPortRanges: [
    //         '139'  //NetBios
    //         '636'  //ldaps
    //         '3268' //global catalog
    //         '3269' //global catalog
    //       ]
    //       access: 'Allow'
    //     }
    //   }
    //   {
    //     name: 'AllowUDPandTCPInbound'
    //     properties: {
    //       direction: 'Inbound'
    //       priority: 1002
    //       protocol: '*'
    //       sourceAddressPrefix: 'VirtualNetwork'
    //       sourcePortRange: '*'
    //       destinationAddressPrefix: IDSnetADCIDR
    //       destinationPortRanges: [
    //         '135' //RPC
    //         '389' //ldap
    //         '445' //SMB
    //         '464' //Kerberos password change
    //         '53'  //DNS
    //         '88'  //Kerberos Authentication
    //       ]
    //       access: 'Allow'
    //     }
    //   }
    // ]
    diagnosticWorkspaceId: LAWorkspace.id
    diagnosticLogCategoriesToEnable:[
      'NetworkSecurityGroupEvent'
      'NetworkSecurityGroupRuleCounter'
    ]
  }
}

//Get the Boundary VNET
resource BoundaryVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: BoundaryVnetName
  scope: resourceGroup(RGBoundary)
}

//ADD Service Endpoints for storage to snet
//Create the Identity VNET and subnets
module IdentityVnet '../MSResourceModules/modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'IdentityVnet'
  scope: IDRG
  params: {
    location: location
    name: IDVnetName
    tags: tags
    addressPrefixes: [
      IDVnetCIDR
    ]
    subnets: [
      {
        name: IDSnetADName
        addressPrefix: IDSnetADCIDR
        networkSecurityGroupId: IdentityADNSG.outputs.resourceId
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
          {
            service: 'Microsoft.Keyvault'
          }
        ]
      }
    ]
    virtualNetworkPeerings: [
      {
        allowForwardedTraffic: false
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: false
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'BoundaryVnet'
        remoteVirtualNetworkId: BoundaryVnet.id
        useRemoteGateways: false
      }
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
    diagnosticLogCategoriesToEnable: [
      'VMProtectionAlerts'
    ]
    diagnosticWorkspaceId: LAWorkspace.id
  }
}

//configure Private DNS Zones relevant for this environment and link it to the AD vnet
module privateDnsZones '../MSResourceModules/modules/Microsoft.Network/privateDnsZones/deploy.bicep' = [for (pdnsName,i) in privateDNSZones  : {
  name: 'privateDnsZones${i}'
  scope: IDRG
  params: {
    location: 'global'
    tags: tags
    name: pdnsName
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: IdentityVnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}]

//Set the container to anonymous?  Seems a bit odd, but it does work - needs debugging.

//Create the storage account required for the script which will build the ADDS server
module ScriptStorage '../MSResourceModules/modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'ScriptStorage'
  scope: IDRG
  params: {
    location: location
    tags: tags
    name: ScriptStorageAccName
    allowBlobPublicAccess: true   //Permits access from the deploying script
    publicNetworkAccess: 'Enabled'
    diagnosticLogsRetentionInDays: 7
    diagnosticWorkspaceId: LAWorkspace.id
    storageAccountSku: 'Standard_LRS'
    blobServices: {
      containers: [
        {
          name: scriptContainerName
          publicAccess: 'Blob'
        }
      ]
      diagnosticWorkspaceId: LAWorkspace.id
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          action: 'Allow'
          value: localScriptIPAddress
        }
      ]
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: IdentityVnet.outputs.subnetResourceIds[indexOf(IdentityVnet.outputs.subnetNames, IDSnetADName)]
        }
      ]
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            privateDnsZones[0].outputs.resourceId
          ]
        }
        service: 'blob'
        subnetResourceId: IdentityVnet.outputs.subnetResourceIds[indexOf(IdentityVnet.outputs.subnetNames, IDSnetADName)]
      }
    ]
  }
}

module ADKeyVault '../MSResourceModules/modules/Microsoft.KeyVault/vaults/deploy.bicep' = {
  name: 'ADKeyVault'
  scope: IDRG
  params: {
    location: location
    tags: tags
    name: ADKeyVaultName
    secrets: {
      secureList: [
        {
          contentType: 'String'
          name: 'ADAdminPassword'
          value: VMADAdminPassword
        }
        {
          contentType: 'String'
          name: 'ADAdminSafeModePassword'
          value: domainSafeModePass
        }
        {
          contentType: 'String'
          name: 'ADAdminUsername'
          value: VMADAdminUserName
        }
      ]
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            privateDnsZones[3].outputs.resourceId
          ]
        }
        service: 'vault'
        subnetResourceId: IdentityVnet.outputs.subnetResourceIds[indexOf(IdentityVnet.outputs.subnetNames, IDSnetADName)]
      }
    ]
  }
}

output identityVnetName string = IDSnetADName
output identitySnetName string = IDVnetName

output identityADSnetId string = IdentityVnet.outputs.subnetResourceIds[indexOf(IdentityVnet.outputs.subnetNames, IDSnetADName)]
output storageAccountName string = ScriptStorage.outputs.name
output storageAccountRG string = ScriptStorage.outputs.resourceGroupName

output environmentOutput object = environment()
