param location string
param policyName string
param skuTier string = 'Standard'
param threatIntelMode string = 'Alert'

// Main firewall policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: policyName
  location: location
  properties: {
    sku: {
      tier: skuTier
    }
    threatIntelMode: threatIntelMode
  }
}

// Rule Collection Group with parent syntax
resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: firewallPolicy  // Simplified parent reference
  name: 'DefaultNetworkRules'  // Child resource name only
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRules'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureCloud'
            ipProtocols: ['Any']
            sourceAddresses: ['*']
            destinationAddresses: ['AzureCloud.${location}']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

output policyId string = firewallPolicy.id
output ruleCollectionGroupId string = ruleCollectionGroup.id
