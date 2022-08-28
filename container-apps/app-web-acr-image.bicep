@description('Name of Container App')
param container_app_name string

@description('Name of your Container Apps Environment')
param environment_name string

@description('Location where to create the resources')
param location string = resourceGroup().location

@description('Existing User Managed Identity Resource Id. If empty, new User Managed Identity will be created')
param user_assigned_identity_id string

@description('Name of the User Assigned Identity to create')
param user_assigned_identity_name string

@minLength(5)
@maxLength(50)
@description('Name of the Azure Container Registry')
param acr_name string

@description('Alphanumeric revision suffix for the Container App')
param revision string

@description('Name of the container image')
param container_image_repository string

@description('SHA256 digest of the image, in format sha256:<digest>')
param container_image_sha256_digest string

@description('Enable Dapr')
param dapr_enable bool


resource environment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: environment_name
}

resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: acr_name  
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = if (empty(user_assigned_identity_id)) {
  name: user_assigned_identity_name
  location: location
}

@description('This is the built-in AcrPull role')
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource userAssignedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (empty(user_assigned_identity_id)){
  scope: acr
  name: guid(acr.id,userAssignedIdentity.id,contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: container_app_name
  location: location
  dependsOn:[
    userAssignedIdentityRoleAssignment
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: (empty(user_assigned_identity_id)) ? json('{"${userAssignedIdentity.id}":{}}') : json('{"${user_assigned_identity_id}":{}}')
  }
  properties: {    
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'multiple'      
      registries: [
        {
          server: acr.properties.loginServer
          identity: (empty(user_assigned_identity_id)) ? userAssignedIdentity.id : user_assigned_identity_id
        }
      ]
      ingress: {
        external: true
        targetPort: 3000
        traffic: [          
          {            
            revisionName: '${container_app_name}--${revision}'
            label: 'latest'                        
            weight: 100
          }   
          /*
          {            
            revisionName: '${container_app_name}--<PREVIOUS REVISION>'            
            weight: 90
          }  
          {            
            revisionName: '${container_app_name}--${revision}'
            label: 'latest'                        
            weight: 10
          }   
          */      
        ]
      }           
      dapr: {
        enabled: dapr_enable
        appId: container_app_name       
        appPort: 3000
        appProtocol: 'http'
      }       
    }
    template: {
      revisionSuffix: revision
      containers: [
        {
          image: '${acr.properties.loginServer}/${container_image_repository}@${container_image_sha256_digest}'
          name: container_app_name  
          env:[
            {
              name: 'PORT'
              value: '3000'
            }
          ]        
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }          
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
         {
            name: 'http-rule'
            http: {
              metadata: {
                concurentRequests: '10'
              }
            }          
          }         
        ]        
      }
    }
  }
}
