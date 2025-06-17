param location string

targetScope = 'resourceGroup'

// Log Analytics Workspace
resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'law-justsa-${uniqueString(resourceGroup().id)}'  // Fixed formatting
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true  // Fixed typo ("enabledog" → "enable")
    }
  }
}

output logAnalyticsWorkspaceId string = law.properties.customerId
