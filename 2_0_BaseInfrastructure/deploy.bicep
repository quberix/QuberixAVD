//Configure the base line infrastructure for the deployment
//This BICEP file relies on the MSRersourceModules folder which in turn is a git submodule of https://github.com/Azure/ResourceModules.git

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

//RGs
@description ('The name of the Log Analytics Workspace Resource Group')
param RGLAW string = toUpper('${productShortName}-RG-Logs-${localenv}')

@description('The name of the Infrastructure Resource Group')
param RGInfra string = toUpper('${productShortName}-RG-Boundary-${localenv}')

//LAW workspace
@description('Log Analytics Workspace Name')
param LAWorkspaceName string = toLower('${productShortName}-LAW-${localenv}')

//boundary Vnet
@description('The name of the boundary Virtual Network')
param boundaryVnetName string = toLower('${productShortName}-boundary-vnet-${localenv}')

@description('The CIDR of the boundary Virtual Network')
param boundaryVnetCIDR string = '10.245.0.0/24'

//boundary bastion
@description('The name of the Bastion in the boundary Virtual Network')
param boundaryBastionName string = toLower('${productShortName}-bastion-${localenv}')

@description('The CIDR of the AzureBastionSubnet subnet in the boundary Virtual Network')
param boundaryVnetBastionCIDR string = '10.245.0.0/26'

@description('The name of the AzureBastionSubnet NSG')
param boundaryNSGBastionName string = toLower('${productShortName}-boundary-nsg-${localenv}')


//Deployment flags
@description('Deploy the Bastion Host (true/false)')
param DeployBastion bool = true

//VARIABLES


//RESOURCES

//Deploy Resource Group
resource LAWRG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGLAW
  location: location
  tags: tags
}

resource InfraRG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGInfra
  location: location
  tags: tags
}

//Deploy Log Analytics (using MS defined resource modules - https://github.com/Azure/ResourceModules/tree/main/modules/Microsoft.OperationalInsights/workspaces )
module LAWorkspace '../MSResourceModules/modules/microsoft.operationalinsights/workspaces/deploy.bicep' = {
  name: 'LAWorkspace'
  scope: LAWRG
  params: {
    location: location
    name: LAWorkspaceName
    tags: tags
    diagnosticLogsRetentionInDays: 30
    serviceTier: 'PerGB2018'
  }
}

//Deploy the boundary virtual network components
//Create the boundary Bastion NSG and required rules
module boundaryBastionNSG '../MSResourceModules/modules/Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  name: 'boundaryNSGBastion'
  scope: InfraRG
  params: {
    location: location
    name: boundaryNSGBastionName
    tags: tags
    securityRules: [
      //Inbound
      {
        name: 'AllowHttpsInbound'
        properties: {
          direction: 'Inbound'
          priority: 1000
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          access: 'Allow'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          direction: 'Inbound'
          priority: 1001
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          access: 'Allow'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          direction: 'Inbound'
          priority: 1002
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          access: 'Allow'
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          direction: 'Inbound'
          priority: 1003
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          access: 'Allow'
        }
      }
      //Outbound
      {
        name: 'AllowSshRDPOutbound'
        properties: {
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          access: 'Allow'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          direction: 'Outbound'
          priority: 1001
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
          access: 'Allow'
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties: {
          direction: 'Outbound'
          priority: 1002
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          access: 'Allow'
        }
      }
      {
        name: 'AllowGetSessionInformation'
        properties: {
          direction: 'Outbound'
          priority: 1003
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '80'
          access: 'Allow'
        }
      }
    ]
    diagnosticWorkspaceId: LAWorkspace.outputs.resourceId
    diagnosticLogCategoriesToEnable:[
      'NetworkSecurityGroupEvent'
      'NetworkSecurityGroupRuleCounter'
    ]
  }
}

//Create the boundary VNET and subnets
module boundaryVnet '../MSResourceModules/modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'boundaryVnet'
  scope: InfraRG
  params: {
    location: location
    name: boundaryVnetName
    tags: tags
    addressPrefixes: [
      boundaryVnetCIDR
    ]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: boundaryVnetBastionCIDR
        networkSecurityGroupId: boundaryBastionNSG.outputs.resourceId
      }
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
    diagnosticLogCategoriesToEnable: [
      'VMProtectionAlerts'
    ]
    diagnosticWorkspaceId: LAWorkspace.outputs.resourceId
  }
}


//Create a Basic Bastion
module boundaryBastion '../MSResourceModules/modules/Microsoft.Network/bastionHosts/deploy.bicep' = if (DeployBastion) {
  name: 'boundaryBastion'
  scope: InfraRG
  params: {
    location: location
    name: boundaryBastionName
    tags: tags
    vNetId: boundaryVnet.outputs.resourceId
    isCreateDefaultPublicIP: true
    diagnosticWorkspaceId: LAWorkspace.outputs.resourceId
    diagnosticLogCategoriesToEnable: [
      'BastionAuditLogs'
    ]
  }
  dependsOn:[
    boundaryBastionNSG
    boundaryVnet
  ]
}
