@minLength(1)
@maxLength(63)
param dns_zone_name string
param vnet_id string

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: dns_zone_name  
}

resource privateDnsZone_vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZone
  name: '${privateDNSZone}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet_id
    }
  }
}
