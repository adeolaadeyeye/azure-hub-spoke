param location string
param logAnalyticsWorkspaceId string
param environment string = 'prod'  // 'prod' or 'nonprod'

// ========== NSG DEPLOYMENTS ========== //
module nsgBastion 'modules/nsg-bastion.bicep' = {
  name: 'nsg-bastion-deploy'
  params: {
    location: location
    environment: environment
  }
}

module nsgAppGw 'modules/nsg-appgw.bicep' = {
  name: 'nsg-appgw-deploy'
  params: {
    location: location
    environment: environment
  }
}

module nsgShared 'modules/nsg-shared.bicep' = {
  name: 'nsg-shared-deploy'
  params: {
    location: location
    environment: environment
  }
}

// ========== HUB VNET ========== //
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-hub-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  tags: {
    environment: environment
    type: 'hub'
  }
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/26'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/26'
          networkSecurityGroup: {
            id: nsgBastion.outputs.nsgId
          }
        }
      }
      {
        name: 'AppGatewaySubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: nsgAppGw.outputs.nsgId
          }
        }
      }
      {
        name: 'SharedSubnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
          networkSecurityGroup: {
            id: nsgShared.outputs.nsgId
          }
        }
      }
    ]
  }
}

// ========== FIREWALL POLICY ========== //
module fwPolicy 'modules/firewallPolicy.bicep' = {
  name: 'fw-policy-${environment}-deploy'
  params: {
    location: location
    environment: environment
    policyName: 'fw-policy-${environment}'
    skuTier: 'Standard'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ========== FIREWALL ========== //
module firewall 'modules/firewall.bicep' = {
  name: 'firewall-${environment}-deploy'
  params: {
    location: location
    vnetName: vnet.name
    subnetName: 'AzureFirewallSubnet'
    firewallPolicyId: fwPolicy.outputs.policyId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    environment: environment
    firewallName: 'fw-${environment}'
    publicIpName: 'pip-fw-${environment}'
  }
}

// ========== WAF (PROD ONLY) ========== //
module waf 'modules/waf.bicep' = if (environment == 'prod') {
  name: 'waf-prod-deploy'
  params: {
    location: location
    vnetName: vnet.name
    subnetName: 'AppGatewaySubnet'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    environment: environment
  }
}

// ========== BASTION HOST ========== //
module bastion 'modules/bastion.bicep' = {
  name: 'bastion-${environment}-deploy'
  params: {
    location: location
    vnetName: vnet.name
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ========== OUTPUTS ========== //
output vnetId string = vnet.id
output vnetName string = vnet.name
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output fwPolicyId string = fwPolicy.outputs.policyId
output wafPublicIp string = (environment == 'prod') ? waf.outputs.wafPublicIp : ''
output bastionPublicIp string = bastion.outputs.bastionPublicIp
output bastionSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureBastionSubnet')
