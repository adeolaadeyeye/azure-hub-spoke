param location string
param environment string

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-shared-${environment}'
  location: location
  tags: {
    purpose: 'shared-services'
    environment: environment
  }
  properties: {
    securityRules: [
      {
        name: 'AllowFromHub'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '10.0.0.0/16'  // Hub VNet
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

output nsgId string = nsg.id
