param location string
param vnetName string
param environment string = 'prod'
param logAnalyticsWorkspaceId string = ''

var bastionName = 'bst-${environment}-${uniqueString(resourceGroup().id)}'
var bastionSku = (environment == 'prod') ? 'Premium' : 'Standard'
var bastionScale = (environment == 'prod') ? 2 : 2  // Minimum is 2 to avoid BCP329

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${bastionName}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: (environment == 'prod') ? ['1', '2', '3'] : []
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    ddosSettings: {
      protectionMode: 'Enabled'
    }
  }
}

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
    enableTunneling: true
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
    scaleUnits: bastionScale
    disableCopyPaste: false
    dnsName: (environment == 'prod') ? 'bst-${environment}-${location}' : ''
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${bastionName}'
  scope: bastion
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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
