param location string
param logAnalyticsWorkspaceId string
param policyName string = 'fw-policy-${uniqueString(resourceGroup().id)}'  // Unique naming

// Premium Firewall Policy with enhanced security features
resource policy 'Microsoft.Network/firewallPolicies@2023-05-01' = {  // Updated API version
  name: policyName
  location: location
  properties: {
    sku: { 
      tier: 'Premium' 
    }
    dnsSettings: { 
      enableProxy: true
      requireProxyForNetworkRules: true
      servers: ['1.1.1.1', '8.8.8.8']  // Explicit DNS servers
    }
    threatIntelWhitelist: {  // Added whitelist
      ipAddresses: [
        '13.66.60.119/32',  // Microsoft Windows Update
        '40.117.80.0/20'    // Azure Storage
      ]
      fqdns: [
        '*.windowsupdate.com'
      ]
    }
    intrusionDetection: { 
      mode: 'Alert'
      configuration: {  // IDPS signatures
        signatureOverrides: [
          { id: '2000000', mode: 'Deny' }  // Example critical signature
        ]
      }
    }
    tlsInspection: { 
      enabled: true 
      requireClientCertificate: false  // Explicit setting
    }
    explicitProxy: {  // Additional proxy settings
      enablePacFile: false
      httpPort: 80
      httpsPort: 443
    }
  }
}

// Enhanced Diagnostic Settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${policyName}'
  scope: policy
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { 
        category: 'AzureFirewallNetworkRule'
        enabled: true
        retentionPolicy: {  // Added retention
          days: 90,
          enabled: true
        }
      },
      { 
        category: 'AzureFirewallApplicationRule' 
        enabled: true
        retentionPolicy: {
          days: 90,
          enabled: true
        }
      },
      { 
        category: 'AzureFirewallDnsProxy'
        enabled: true
        retentionPolicy: {
          days: 90,
          enabled: true
        }
      }
    ]
    metrics: [  // Added metrics collection
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 90,
          enabled: true
        }
      }
    ]
  }
}

output policyId string = policy.id
output policyName string = policy.name  // Added for reference
