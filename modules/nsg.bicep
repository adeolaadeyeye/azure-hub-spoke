param location string
param vnetName string
param subnetNames array  // Now supports multiple subnets
param allowedFwIp string
param environment string = 'prod'  // For rule tagging

// Updated to latest API version
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  tags: {
    environment: environment
    managedBy: 'Bicep'
  }
  properties: {
    securityRules: [
      // Allow Azure infrastructure
      {
        name: 'AllowAzureInfra'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      // Allow traffic from firewall
      {
        name: 'AllowFromFW'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: allowedFwIp
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      // Allow intra-subnet communication
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      // Default deny rule
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Apply NSG to all specified subnets
resource nsgAssociations 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = [for subnetName in subnetNames: {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: reference(resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)).addressPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
    privateEndpointNetworkPolicies: contains(subnetName, 'Data') ? 'Enabled' : 'Disabled'
  }
}]

output nsgId string = nsg.id
output nsgName string = nsg.name
