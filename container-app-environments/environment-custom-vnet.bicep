@description('Environment name')
param environment_name string

@description('Environment location. By default, same as the resource group')
param location string = resourceGroup().location

@description('Deploy an internal VNET only environment')
param internal_environment bool

@description('Deploy accros availability zones')
param zone_redundant bool = true

@description('Existing subnet to use for the environment. If not specified, will create new vnet and subnet')
param subnet_id string  //if not specified, it will create a new subnet

@description('Name of the vnet to create')
param vnet_name string 
@description('CIDR for the vnet')
param vnet_address_cidrs array 

@description('Name of the subnet to create')
param subnet_name string 
@description('CIDR for the subnet')
param subnet_address_cidr string 

@description('For new vnet/subnets, if not empty, will create an NSG to allow HTTPs access only from the specified list of IPs')
param nsg_allowed_ips array // comma-separated list of IP address from where to allow HTTPs traffic to the ingress. Doesn't work with existing subnets, created outside of this deployment stack
@description('Name of the NSG for the nsg_allowed_ips list')
param nsg_name string = 'nsg-${subnet_name}'

@description('Name of the Log Analytics')
var log_analytics_workspace_name = 'logs-${environment_name}'

@description('Retention time of the logs')
param log_analytics_retention_days int = 30

@description('Deploy Azure Container Registry')
param acr_deploy bool

@minLength(5)
@maxLength(50)
@description('Globally unique name for Azure Container Registry')
param acr_name string = 'acr${uniqueString(resourceGroup().id)}'

@description('SKU for Azure Container Registry')
@allowed(['Basic','Standard','Premium'])
param acr_sku string = 'Basic'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-03-01' = if (empty(subnet_id)) {
  name: vnet_name
  location: location
  properties:{
    addressSpace: {
      addressPrefixes: vnet_address_cidrs
    }
    subnets:[
      {
        name: subnet_name
        properties:{
          addressPrefix: subnet_address_cidr          
        }
      }
    ]
  }
}


resource logAnalyticsWorkspace'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: log_analytics_workspace_name
  location: location
  properties: {
    retentionInDays: log_analytics_retention_days    
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: environment_name
  location: location
  properties: { 
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspace.id, '2021-06-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-06-01').primarySharedKey
      }
    } 
    vnetConfiguration:{
      infrastructureSubnetId: (!empty(subnet_id)) ? subnet_id : '${virtualNetwork.id}/subnets/${subnet_name}'
      internal: internal_environment      
    } 
    zoneRedundant:zone_redundant  
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-08-01' = if (!empty(nsg_allowed_ips) && empty(subnet_id)) {
  name: nsg_name
  location: location
  properties:{
    securityRules:[
      {
        name: 'Allow_Internet_HTTPS_Inbound'
        properties: {
          description: 'Allow inbound internet connectivity for HTTPS only.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefixes: nsg_allowed_ips
          destinationAddressPrefix: environment.properties.staticIp
          access: 'Allow'
          priority: 400
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource attachNSGToSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = if (empty(subnet_id)){  
  name: subnet_name
  parent:  virtualNetwork  
  properties:{
    addressPrefix: subnet_address_cidr          
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }

}

module privateDNSZoneModule 'modules/create-private-dns-zone/main.bicep' = if (internal_environment){
  name: 'privateDNSZone'
  params: {
    dns_zone_name: environment.properties.defaultDomain
  }
}

module linkPrivateDNSZoneToVnetModule 'modules/link-private-dns-zone-to-vnet/main.bicep' = if (internal_environment){
  name: 'privateDNSZoneLink'
  params: {
    dns_zone_name: environment.properties.defaultDomain
    vnet_id: virtualNetwork.id
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = if (acr_deploy){
  name: acr_name
  location: location
  sku: {
    name: acr_sku
  }
  properties: {
    adminUserEnabled: false
  }
}
