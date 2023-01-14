//PARAMETERS
@description('Tags for the deployed resources')
param tags object

@description('Geographic Location of the Resources.')
param location string = resourceGroup().location

param publicIPAddressName string

@allowed([
  'Standard'
  'Basic'
])
param publicIPSKU string = 'Basic'

@allowed([
  'Static'
  'Dynamic'
])
param publicIPType string = 'Dynamic'

@allowed([
  'Global'
  'Regional'
])
param publicIPRegion string = 'Regional'

//Create the Public IP Address
resource PIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: publicIPAddressName
  location: location
  tags: tags
  sku: {
    name: publicIPSKU
    tier: publicIPRegion
  }
  properties: {
    publicIPAllocationMethod: publicIPType
  }
}

output id string = PIP.id
output ipAddress string = PIP.properties.ipAddress
