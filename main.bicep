targetScope = 'subscription'

param location string = 'eastus'
param resourceGroupName string = 'rg-justsa-hubspoke-${uniqueString(subscription().id)}'
param environment string = 'prod'  // 'prod' or 'nonprod'

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-05-01' = {
  name: resourceGroupName
  location: location
  tags: {
    environment: environment
    workload: 'hub-spoke'
  }
}

// Deploy monitoring (LAW + Diagnostics)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deploy'
  scope: rg
  params: {
    location: location
    environment: environment
  }
}

// Deploy hub network with all components (now includes WAF/Bastion)
module hub 'hub-network.bicep' = {
  name: 'hub-network-deploy'
  scope: rg
  dependsOn: [
    monitoring
  ]
  params: {
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    environment: environment
  }
}

// Spoke deployments (conditional based on environment)
module spokeProd 'spoke-prod.bicep' = if (environment == 'prod') {
  name: 'spoke-prod-deploy'
  scope: rg
  dependsOn: [
    hub
  ]
  params: {
    location: location
    hubVnetId: hub.outputs.vnetId
    fwPrivateIp: hub.outputs.firewallPrivateIp
  }
}

module spokeNonProd 'spoke-nonprod.bicep' = if (environment == 'nonprod') {
  name: 'spoke-nonprod-deploy'
  scope: rg
  dependsOn: [
    hub
  ]
  params: {
    location: location
    hubVnetId: hub.outputs.vnetId
    fwPrivateIp: hub.outputs.firewallPrivateIp
  }
}

// Outputs for integration
output lawWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output hubVnetId string = hub.outputs.vnetId
output bastionPublicIp string = hub.outputs.bastionPublicIp
output wafPublicIp string = hub.outputs.wafPublicIp
