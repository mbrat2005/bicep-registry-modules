provider microsoftGraph

param location string
param keyId string = newGuid()
param arbDeploymentAppCredEnd string
param now string = utcNow('yyyy-MM-ddTHH:mm:ssZ')

// TO-DO: Bicep Graph does not support adding client secret permissions to service principals or apps. This may be a viable solution when HCI moves away from client secrets.
/* resource clientApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'hciArcRB'
  displayName: 'hciArcRB'
  signInAudience: 'AzureADMyOrg'
  web: {
    redirectUris: []
    implicitGrantSettings: { enableIdTokenIssuance: true }
  }
  requiredResourceAccess: []
}

// https://learn.microsoft.com/en-us/graph/templates/known-issues-graph-bicep?view=graph-bicep-1.0#application-passwords-are-not-supported-for-applications-and-service-principals
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appRoleAssignmentRequired: false
  displayName: 'hciArcRB'
  oauth2PermissionScopes: []
  servicePrincipalNames: ['hciArcRB']
  appId: clientApp.appId
} */

// get the service principal for the hciRP
resource hciRPServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: '1412d89f-b8a8-4111-b4fd-e82905cbd85d'
}

//output servicePrincipalSecret string = servicePrincipal.passwordCredentials[0].secretText
//output servicePrincipalId string = servicePrincipal.id
//output servicePrincipalAppId string = servicePrincipal.appId
output hciRPServicePrincipalId string = hciRPServicePrincipal.id