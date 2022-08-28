@description('Environment name')
param environment_name string

@description('Environment location. By default, same as the resource group')
param location string = resourceGroup().location

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
