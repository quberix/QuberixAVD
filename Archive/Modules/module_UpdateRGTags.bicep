//Redeploy the Resource Group with the additional tags added
@description('Required - Tags for the deployed resources')
param tags object = {}

@description('Optional - Geographic Location of the Resources.  Default: same as resource group')
param location string

@description('The name of the existing RG that has already been deployed and requires its Tags updating')
param rgName string



//As this is an RG deployment it must be run at the subscription scope
targetScope = 'subscription'

resource RG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}
