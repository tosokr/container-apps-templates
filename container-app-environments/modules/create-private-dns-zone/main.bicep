@minLength(1)
@maxLength(63)
param dns_zone_name string

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dns_zone_name  
}
