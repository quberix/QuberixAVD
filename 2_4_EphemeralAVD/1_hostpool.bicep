// Deploys a traditional AVD soltion based on the image genersated in step 2.2
// this will build a number of hosts, add them to the domain and then create and add them to the host pool
// it will also create a scheduler to scale the solution up and down.

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
param productShortName string

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  Product: productShortName
}

@description('The name of the resource group to create for the common image builder components')
param RGAVDName string = toUpper('${productShortName}-RG-AVD-STD-${localenv}')

//LAW Resource Group name
@description ('The name of the Log Analytics Workspace Resource Group')
param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

//LAW workspace
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')


//Host Pool parameters
@description('The name of the host pool')
param hostPoolName string = toLower('${productShortName}-HP-${localenv}')

@description('The friendly name of the host pool')
param hostPoolFriendlyName string = '${productShortName}-Desktop-${localenv}'

@description('The description of the host pool')
param hostPoolDescription string = 'The ${productShortName} standard desktop host pool'

@description('The name of the host pools application group')
param hostPoolAppGroupName string = toLower('${productShortName}-HP-AG-${localenv}')

@description('The friendly name of the Application Group')
param hostPoolAppGroupFriendlyName string = '${productShortName}-AppGroup-${localenv}'

@description('The name of the host pools workspace')
param hostPoolWorkspaceName string = toLower('${productShortName}-HP-WS-${localenv}')

@description('The friendly name of the host pool workspace')
param hostPoolWorkspaceFriendlyName string = '${productShortName}-Workspace-${localenv}'

@description('The type of the host pool to deploy')
param hostPoolType string = 'Pooled'

@description('The RDP properties string to apply to the host pool')
param hostPoolRDPProperties string = 'audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;compression:i:1;videoplaybackmode:i:1;redirectlocation:i:0;redirectwebauthn:i:1;use multimon:i:1;dynamic resolution:i:1'

@description('The maximum number of sessions to allow in the host pool')
param hostPoolMaxSessionLimit int = 100

@description('The load balancer type to use for the host pool') 
param hostPoolLoadBalancerType string = 'BreadthFirst'

@description('The time in minutes before a token expires')
param hostPoolTokenExpiryTime string = 'PT12H'

@description('The type of disk to use for the host pool VMs')
param hostPoolVMDiskType string = 'StandardSSD_LRS'

@description('The prefix to use for the host names')
param hostPoolHostNamePrefix string = toLower('${productShortName}avdstd')

param hostPoolVMSize object = {
  id: 'Standard_D2s_v3'
  cores: 2
  ram: 8
}

//Active Directory Settings
@description('The name of the AD domain to join the hosts to')
param adDomainName string = 'quberatron.com'

param adServerIPAddresses array = [
  '10.245.8.20'
]

//Virtual Network
@description('The name of the virtual network')
param avdVnetName string = toLower('${productShortName}-vnet-${localenv}')

@description('The address space of the virtual network')
param avdVnetCIDR string = '10.245.16.1/24'

@description('The name of the AVD Host subnet to create')
param avdSubnetName string = toLower('${productShortName}-snet-avdhost-${localenv}')

@description('The CIDR of the AVD Host subnet to create')
param avdSubnetCIDR string = '10.245.16.1/24'

@description('The Name of the NSG to apply to the AVD Host subnet')
param avdNSGName string = toLower('${productShortName}-nsg-avdhost-${localenv}')

//Identity network settings
@description('The Name of the AD VNET to peer to')
param identityVnetName string = toLower('${productShortName}-identity-vnet-${localenv}')

@description('The RG of the AD VNET to peer to')
param identityVnetRG string = toUpper('${productShortName}-RG-IDENTITY-${localenv}')

@description('The subscription of the AD VNET to peer to')
param identityVnetSubscriptionId string = subscription().subscriptionId

//Boundary Network Settings
@description('The name of the boundary network')
param boundaryVnetName string = toLower('${productShortName}-boundary-vnet-${localenv}')

@description('The RG of the AD VNET to peer to')
param boundaryVnetRG string = toUpper('${productShortName}-RG-BOUNDARY-${localenv}')

@description('The subscription of the AD VNET to peer to')
param boundaryVnetSubscriptionId string = subscription().subscriptionId

//Image Builder Compute Gallery settings
@description('The Resource Group name where the Compute Gallery is located that hosts the image builder image')
param galleryRG string = toUpper('${productShortName}-RG-IMAGES-${localenv}')

@description('The subscription where the Compute Gallery is located')
param gallerySubscriptionId string = subscription().subscriptionId

@description('The name of the Compute Gallery')
param galleryName string = toLower('${productShortName}_cgal_${localenv}')

@description('The name of the Compute Gallery Image to use')
param galleryImageName string = 'QBXDesktop'

// @description('The version of the Compute Gallery Image to use')
// param galleryImageVersion string = 'latest'

//RESOURCES
//Create the RG
resource RGAVDSTD 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGAVDName
  location: location
  tags: tags
}

//Retrieve the CORE Log Analytics workspace
resource LAWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LAWorkspaceName
  scope: resourceGroup(RGLAW)
}

//Pull in the Compute Gallery
resource ComputeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: galleryName
  scope: resourceGroup(gallerySubscriptionId,galleryRG)
}

resource ComputeGalleryImage 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: galleryImageName
  parent: ComputeGallery
}

//Pull in the AD VNET to peer to
resource IdentityVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: identityVnetName
  scope: resourceGroup(identityVnetSubscriptionId,identityVnetRG)
}

//Pull in the Boundary VNET to peer to (access to firewall and bastion)
resource BoundaryVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: boundaryVnetName
  scope: resourceGroup(boundaryVnetSubscriptionId,boundaryVnetRG)
}

//Create the AVD NSG
module avdNSG '../MSResourceModules/modules/Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  name: 'boundaryNSGBastion'
  scope: RGAVDSTD
  params: {
    location: location
    name: avdNSGName
    tags: tags
    securityRules: [
      //Inbound
      {
        name: 'AllowRDPInbound'
        properties: {
          direction: 'Inbound'
          priority: 1000
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          access: 'Allow'
        }
      }
    ]
    diagnosticWorkspaceId: LAWorkspace.id
    diagnosticLogCategoriesToEnable:[
      'NetworkSecurityGroupEvent'
      'NetworkSecurityGroupRuleCounter'
    ]
  }
}

//Create the STD AVD VNET and subnet and peer to the AD subnet
module AVDVnet '../MSResourceModules/modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'boundaryVnet'
  scope: RGAVDSTD
  params: {
    location: location
    name: avdVnetName
    tags: tags
    addressPrefixes: [
      avdVnetCIDR
    ]
    subnets: [
      {
        name: avdSubnetName
        addressPrefix: avdSubnetCIDR
        networkSecurityGroupId: avdNSG.outputs.resourceId
      }
    ]
    dnsServers: adServerIPAddresses
    virtualNetworkPeerings: [
      {
        allowForwardedTraffic: false
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: false
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: '${identityVnetName}-to-${avdVnetName}'
        remoteVirtualNetworkId: IdentityVnet.id
        useRemoteGateways: false
      }
      {
        allowForwardedTraffic: false
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: false
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: '${boundaryVnetName}-to-${avdVnetName}'
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

//Create the host pool
module DesktopHostPool '../MSResourceModules/modules/Microsoft.DesktopVirtualization/hostpools/deploy.bicep' = {
  name: 'DesktopHostPool'
  scope: RGAVDSTD
  params: {
    name: hostPoolName
    location: location
    customRdpProperty: hostPoolRDPProperties
    hostpoolFriendlyName: hostPoolFriendlyName
    hostpoolType: hostPoolType
    hostpoolDescription: hostPoolDescription
    maxSessionLimit: hostPoolMaxSessionLimit
    loadBalancerType: hostPoolLoadBalancerType
    tokenValidityLength: hostPoolTokenExpiryTime
    diagnosticWorkspaceId: LAWorkspace.id
    diagnosticLogsRetentionInDays: 7
    vmTemplate: {
      imageType: 'CustomImage'
      customImageId: ComputeGalleryImage.id
      osDiskType: hostPoolVMDiskType
      vmSize: hostPoolVMSize
      useManagedDisks: true
      namePrefix: hostPoolHostNamePrefix
      domain: adDomainName
      
    }
  }
}
//ComputeGalleryDefinition.id

//Create the application group
module DesktopAppGroup '../MSResourceModules/modules/Microsoft.DesktopVirtualization/applicationgroups/deploy.bicep' = {
  name: 'DesktopAppGroup'
  scope: RGAVDSTD
  params: {
    name: hostPoolAppGroupName
    location: location
    applicationGroupType: 'Desktop'
    hostpoolName: DesktopHostPool.outputs.name
    friendlyName: hostPoolAppGroupFriendlyName
    diagnosticWorkspaceId: LAWorkspace.id
  }
}

//Create the workspace
module DesktopWorkspace '../MSResourceModules/modules/Microsoft.DesktopVirtualization/workspaces/deploy.bicep' = {
  name: 'DesktopWorkspace'
  scope: RGAVDSTD
  params: {
    name: hostPoolWorkspaceName
    location: location
    diagnosticWorkspaceId: LAWorkspace.id
    appGroupResourceIds: [
      DesktopAppGroup.outputs.resourceId
    ]
    workspaceFriendlyName: hostPoolWorkspaceFriendlyName
  }
}

output avdSubnetID string = AVDVnet.outputs.subnetResourceIds[indexOf(AVDVnet.outputs.subnetNames,avdSubnetName)]
output hpRG string = RGAVDSTD.name
output hpName string = DesktopHostPool.outputs.name
