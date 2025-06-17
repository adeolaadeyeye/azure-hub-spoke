param location string
param vnetName string
param subnetNames array  # Now supports multiple subnets
param fwPrivateIp string
param routeNamePrefix string = 'default'

# Latest API version with zone redundancy support
resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'rt-${routeNamePrefix}-${uniqueString(resourceGroup().id)}'
  location: location
  tags: {
    managedBy: 'Bicep'
    purpose: 'ForceTunnelViaFirewall'
  }
  properties: {
    disableBgpRoutePropagation: true  # Critical for hybrid networks
    routes: [
      {
        name: 'default-to-fw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fwPrivateIp
        }
      }
      # Add Azure-specific required routes (Example)
      {
        name: 'azure-services'
        properties: {
          addressPrefix: 'AzureCloud.${location}'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

# Apply route table to all specified subnets
resource subnetAssociations 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = [for subnetName in subnetNames: {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: reference(resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)).addressPrefix
    routeTable: {
      id: routeTable.id
    }
    # Preserve existing subnet policies
    privateEndpointNetworkPolicies: reference(resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)).privateEndpointNetworkPolicies
  }
}]

output routeTableId string = routeTable.id
output routeTableName string = routeTable.name
