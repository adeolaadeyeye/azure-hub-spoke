param location string
param vnetName string
param subnetName string
param environment string = 'prod'
param logAnalyticsWorkspaceId string = ''

var wafName = 'waf-${environment}-${uniqueString(resourceGroup().id)}'

// Public IP for WAF
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${wafName}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: (environment == 'prod') ? ['1', '2', '3'] : []
  properties: {
    publicIPAllocationMethod: 'Static'
    ddosSettings: {
      protectionMode: 'Enabled'
    }
  }
}

// WAF Policy Resource
resource wafPolicy 'Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies@2023-05-01' = {
  name: 'waf-policy-${environment}'
  location: location
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: (environment == 'prod') ? 'Prevention' : 'Detection'
    }
    customRules: []
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

// App Gateway with WAF Policy
resource appgw 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: wafName
  location: location
  tags: {
    environment: environment
    managedBy: 'Bicep'
  }
  sku: {
    name: 'WAF_v2'
    tier: 'WAF_v2'
  }
  properties: {
    autoscaleConfiguration: (environment == 'prod') ? {
      minCapacity: 2
      maxCapacity: 5
    } : {
      minCapacity: 1
      maxCapacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'httpPort'
        properties: {
          port: 80
        }
      }
      {
        name: 'httpsPort'
        properties: {
          port: 443
        }
      }
    ]
    sslCertificates: [
      {
        name: 'defaultCert'
        properties: {
          keyVaultSecretId: '' // TODO: Add Key Vault Secret ID
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', wafName, 'frontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', wafName, 'httpsPort')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', wafName, 'defaultCert')
          }
        }
      }
    ]
    firewallPolicy: {
      id: wafPolicy.id
    }
    enableHttp2: true
    forceFirewallPolicyAssociation: true
  }
}

// Diagnostic settings
resource diagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${wafName}'
  scope: appgw
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
        retentionPolicy: {
          days: (environment == 'prod') ? 90 : 30
          enabled: true
        }
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output wafPublicIp string = publicIp.properties.ipAddress
output wafFqdn string = publicIp.properties.dnsSettings.fqdn
