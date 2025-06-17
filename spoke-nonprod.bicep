param location string
param hubVnetId string
param fwPrivateIp string

// NonProd-specific configurations
param environment string = 'nonprod'
param vnetAddressPrefix string = '10.2.0.0/16'  // Different address space
param appSubnetPrefix string = '10.2.1.0/24'
param dataSubnetPrefix string = '10.2.2.0/24'

// Unique naming with nonprod identifier
var vnetName = 'vnet-${environment}-${uniqueString(resourceGroup().id)}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: {
    environment: 'non-production'
    criticality: 'low'
    workload: 'testing'
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
    allowForwardedTraffic: true
    useRemoteGateways: false
  }
}

// Route Table with simplified routes for nonprod
module udr 'modules/udr.bicep' = {
  name: 'udr-${environment}-deploy'
  params: {
    location: location
    vnetName: vnet.name
    subnetNames: [
      'AppSubnet'
      'DataSubnet'
    ]
    fwPrivateIp: fwPrivateIp
    routeNamePrefix: environment
  }
}

// NSG with relaxed rules for nonprod
module nsg 'modules/nsg.bicep' = {
  name: 'nsg-${environment}-deploy'
  params: {
    location: location
    vnetName: vnet.name
    subnetNames: [
      'AppSubnet'
      'DataSubnet'
    ]
    allowedFwIp: fwPrivateIp
    environment: environment
  }
}

output spokeVnetId string = vnet.id
output spokeVnetName string = vnet.name
