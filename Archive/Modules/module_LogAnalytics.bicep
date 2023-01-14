//build the Log Analytics workspace

//PARAMETERS
param tags object
param laName string
param retention int = 30
param sku string = 'PerGB2018'
param location string = resourceGroup().location

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: laName
  location: location
  tags: tags
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: retention
    sku: {
      name: sku
    }
  }
}

output logAnalyticsID string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output logAnalyticsCustomerID string = logAnalytics.properties.customerId
