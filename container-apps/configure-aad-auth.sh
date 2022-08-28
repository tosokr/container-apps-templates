#!/bin/bash
applicationUri='albumapi.redocean-ba669434.westeurope.azurecontainerapps.io' # uri of the application without the protocol part
resourceName='albumapi' # name of the resource (Container App)
resourceGroup='rg-container-apps-bicep-testing' # resource group of the resource

tenantId=$(az account show --query tenantId -o tsv)
issuerUrl='https://sts.windows.net/'$tenantId'/v2.0'
tokenAudiance='api://'${applicationUri}
clientSecretName=App_Secret
clientSecretEndDate=$(date -d '+90 days' +%F) #Keep the client secret valid for 90 days. Create a script to rotate it regulary (soon support in Gyre)
cat > oauth2-permissions.json  << ENDOFFILE
{
api:{
oauth2PermissionScopes:[
      {
        "adminConsentDescription": "Allow the application to access ${applicationUri} on behalf of the signed-in user.",
        "adminConsentDisplayName": "Access ${applicationUri}",
        "id": "`uuidgen`",
        "isEnabled": true,
        "type": "User",
        "userConsentDescription": "Allow the application to access ${applicationUri} on your behalf.",
        "userConsentDisplayName": "Access ${applicationUri}",
        "value": "user_impersonation"
      }
    ]
  }
}
ENDOFFILE

# Create an application registration and add a secret to it
appId=$(az ad app create --display-name $applicationUri --sign-in-audience AzureADMyOrg --enable-id-token-issuance  true --web-home-page-url https://$applicationUri --web-redirect-uris https://$applicationUri/.auth/login/aad/callback --query appId -o tsv)
appSecret=$(az ad app credential reset --id $appId --append --display-name $clientSecretName --end-date $clientSecretEndDate --query password --output tsv)

# Provide User.Read permission to Microsoft.Graph
az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope

# Create the application id uri
az ad app update --id $appId --set identifierUris='["'${tokenAudiance}'"]'

# Create oauth2 permission scope
az rest --url https://graph.microsoft.com/v1.0/applications/`az ad app show --id $appId --query id -o tsv` --method patch --headers 'Content-Type=application/json' --body @oauth2-permissions.json

# Enable Auth on Container Apps
az containerapp auth microsoft update -n $resourceName -g $resourceGroup --allowed-token-audiences $tokenAudiance --client-id $appId --client-secret $appSecret --issuer $issuerUrl --yes