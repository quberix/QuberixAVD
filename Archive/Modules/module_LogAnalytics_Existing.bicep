//Retrieves the correct Log Analytics Workspace and returns it as an ID

@description('Config object containing the details of the LAW instances available for the current environment')
param diagLAWObject object

//VARIABLES
var lawName = diagLAWObject.name
var diagRG = diagLAWObject.rg
var diagSub = diagLAWObject.subscription

//Get the log analytics workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: lawName
  scope: resourceGroup(diagSub,diagRG)
}

output logAnalyticsID string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output logAnalyticsCustomerID string = logAnalytics.properties.customerId
