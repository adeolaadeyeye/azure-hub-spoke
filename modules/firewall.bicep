param location string
param vnetName string
param logAnalyticsWorkspaceId string
param firewallPolicyId string
param subnetName string = 'AzureFirewallSubnet'
param environment string = 'prod'  // 'prod' or 'nonprod'

// Zone configuration based on environment
var zones = (environment == 'prod') ? ['1', '2', '3'] : []

// Public IP with environment-aware naming
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-fw-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: { 
    name: 'Standard' 
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    zones: zones
    ddosSettings: {
      protectionMode: 'Enabled'
    }
  }
}

// Firewall with enhanced security
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: 'azfw-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  zones: zones
  sku: { 
    name: 'AZFW_VNet' 
    tier: 'Premium' 
  }
  properties: {
    firewallPolicy: { 
      id: firewallPolicyId 
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig-${environment}'
        properties: {
          subnet: { 
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName) 
          }
          publicIPAddress: { 
            id: publicIp.id 
          }
        }
      }
    ]
    threatIntelMode: 'Alert'
    hubIPAddresses: {}
    additionalProperties: {
      "Network.SNAT.PrivateRanges": "IANAPrivateRanges"  // Explicit SNAT configuration
    }
  }
}

// Enhanced Diagnostic Settings
resource diagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-fw-${environment}'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
        retentionPolicy: {
          days: (environment == 'prod') ? 90 : 30
          enabled: true
        }
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
        retentionPolicy: {
          days: (environment == 'prod') ? 90 : 30
          enabled: true
        }
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: (environment == 'prod') ? 90 : 30
          enabled: true
        }
      }
    ]
  }
}

output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = publicIp.properties.ipAddress
output firewallName string = firewall.name
