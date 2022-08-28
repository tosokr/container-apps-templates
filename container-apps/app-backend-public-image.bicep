
@description('Name of Container App')
param container_app_name string

@description('Name of your Container Apps Environment')
param environment_name string

@description('Location where to create the resources')
param location string = resourceGroup().location

@description('Container registry login server')
param container_registry_login_server string

@description('Name of the container image')
param container_image_repository string

@description('SHA256 digest of the image, in format sha256:<digest>')
param container_image_sha256_digest string

@description('Enable Dapr')
param dapr_enable bool

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: environment_name
}

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: container_app_name
  location: location  
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'   
      dapr:{
        enabled: dapr_enable
        appId: container_app_name
      }               
    }        
    template: {      
      containers: [
        {
          image: '${container_registry_login_server}/${container_image_repository}@${container_image_sha256_digest}'
          name: 'ubuntu'   
          command: ['/bin/sleep','3650d']       
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }          
        }
      ]            
      scale:{
        minReplicas:1
        maxReplicas:1
      }
    }
  }
}
