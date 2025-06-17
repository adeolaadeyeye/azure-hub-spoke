param location string
param firewallName string
param publicIpName string
param skuTier string = 'Premium'
param threatIntelMode string = 'Alert'

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    // Removed invalid 'zones' property
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      tier: skuTier
    }
    threatIntelMode: threatIntelMode
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnetName', 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output firewallId string = firewall.id
output publicIpId string = publicIp.id
