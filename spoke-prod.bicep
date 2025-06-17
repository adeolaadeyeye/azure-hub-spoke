param location string
param hubVnetId string
param fwPrivateIp string

// Production-specific configurations
param environment string = 'prod'
param vnetAddressPrefix string = '10.1.0.0/16'
param appSubnetPrefix string = '10.1.1.0/24'
param dataSubnetPrefix string = '10.1.2.0/24'
param dmzSubnetPrefix string = '10.1.3.0/24'  // Added DMZ subnet

// Unique naming with production identifier
var vnetName = 'vnet-${environment}-${uniqueString(resourceGroup().id)}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: {
    environment: 'production'
    criticality: 'high'
    workload: 'primary'
  }
  properties: {
    addressSpace: { 
      addressPrefixes: [ vnetAddressPrefix ] 
    }
    subnets: [
      {
        name: 'AppSubnet'
        properties: { 
          addressPrefix: appSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      },
      {
        name: 'DataSubnet'
        properties: { 
          addressPrefix: dataSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
        }
      },
      {
        name: 'DMZSubnet'  // New subnet for public-facing services
        properties: {
          addressPrefix: dmzSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Peering to Hub (bidirectional)
resource peeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'peer-${environment}-to-hub'
  parent: vnet
  properties: {
    remoteVirtualNetwork: { id: hubVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true  // Required for firewall
    useRemoteGateways: false     // Set to true if hub has VPN/ER
  }
}

// Route Table for all subnets
module udr 'modules/udr.bicep' = {
  name: 'udr-${environment}-deploy'
  params: {
    location: location
    vnetName: vnet.name
    subnetNames: [
      'AppSubnet'
      'DataSubnet'
      'DMZSubnet'
    ]
    fwPrivateIp: fwPrivateIp
    routeNamePrefix: environment
  }
}

// NSG with production-specific rules
module nsg 'modules/nsg.bicep' = {
  name: 'nsg-${environment}-deploy'
  params: {
    location: location
    vnetName: vnet.name
    subnetNames: [
      'AppSubnet'
      'DataSubnet'
      'DMZSubnet'
    ]
    allowedFwIp: fwPrivateIp
    environment: environment
  }
}

output spokeVnetId string = vnet.id
output spokeVnetName string = vnet.name
output appSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AppSubnet')
