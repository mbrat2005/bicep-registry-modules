provider microsoftGraph

param keyId string = newGuid()
param now string = utcNow()

resource clientApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'hciArcRB'
  displayName: 'hciArcRB'
  signInAudience: 'AzureADMyOrg'
  web: {
    redirectUris: []
    implicitGrantSettings: { enableIdTokenIssuance: true }
  }
  requiredResourceAccess: []
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appRoleAssignmentRequired: false
  displayName: 'hciArcRB'
  oauth2PermissionScopes: []
  servicePrincipalNames: ['hciArcRB']
  appId: clientApp.appId
  passwordCredentials: [
    {
      displayName: 'hciArcRB'
      endDateTime: now
      keyId: keyId
      startDateTime: now
    }
  ]
}

resource hciRPServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: '1412d89f-b8a8-4111-b4fd-e82905cbd85d'
}

output servicePrincipalSecret string = servicePrincipal.passwordCredentials[0].secretText
output servicePrincipalId string = servicePrincipal.id
output servicePrincipalAppId string = servicePrincipal.appId
output hciRPServicePrincipalId string = hciRPServicePrincipal.id
