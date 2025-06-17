param location string
param vnetName string
param environment string = 'prod'  // Add environment flag
param bastionName string = 'bst-${environment}-${uniqueString(resourceGroup().id)}'

// Premium SKU for production (Standard for nonprod)
var bastionSku = (environment == 'prod') ? 'Premium' : 'Standard'

// Zone-redundant public IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${bastionName}'
  location: location
  sku: { 
    name: 'Standard' 
  }
  zones: (environment == 'prod') ? ['1', '2', '3'] : []  // Zonal redundancy for prod
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    ddosSettings: {  // DDoS protection
      protectionMode: 'Enabled'
    }
  }
}

// Bastion host with scaling and security
resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location: location
  tags: {
    environment: environment
    managedBy: 'Bicep'
  }
  sku: {
    name: bastionSku
  }
  properties: {
    enableTunneling: true  // Enable SSH tunneling
    ipConfigurations: [
      {
        name: 'bastionConfig'
        properties: {
          subnet: { 
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet') 
          }
          publicIPAddress: { 
            id: publicIp.id 
          }
        }
      }
    ]
    // Production-specific hardening
    scaleUnits: (environment == 'prod') ? 2 : 1
    disableCopyPaste: false  // Set to true for higher security
    dnsName: (environment == 'prod') ? 'bst-${environment}-${location}' : ''
  }
}

// Diagnostic settings (critical for auditing)
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (environment == 'prod') {
  name: 'diag-${bastionName}'
  scope: bastion
  properties: {
    workspaceId: ''  // Pass your Log Analytics workspace ID
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
    ]
  }
}

output bastionPublicIp string = publicIp.properties.ipAddress
output bastionFqdn string = bastion.properties.dnsName
