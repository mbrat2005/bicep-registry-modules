@minLength(4)
@maxLength(8)
param deploymentPrefix string

// credentials for the deployment and ongoing lifecycle management
param deploymentUsername string = 'deployUser'

param localAdminUsername string = 'admin-hci'

@secure()
param localAdminPassword string

param arbDeploymentAppId string

param arbDeploymentSPObjectId string

@secure()
param arbDeploymentServicePrincipalSecret string

param hciResourceProviderObjectId string

param clusterNodeNames array = [
  'hciNode1'
  'hciNode2'
]

// retention policy for the Azure Key Vault and Key Vault diagnostics
param softDeleteRetentionDays int = 30

@minValue(0)
@maxValue(365)
param logsRetentionInDays int = 30

@secure()
param adminPassword string

var arcNodeResourceIds = [
  for (nodeName, index) in clusterNodeNames: resourceId('Microsoft.HybridCompute/machines', nodeName)
]

var clusterWitnessStorageAccountName = '${deploymentPrefix}witness'

var keyVaultName = 'kvhci-${deploymentPrefix}'
var tenantId = subscription().tenantId

module hciHostDeployment '../modules/azureStackHCIHost/hciHostDeployment.bicep' = {
  name: 'hciHostDeployment'
  params: {
    location: 'eastus'
    adminPassword: adminPassword
  }
}

module hciClusterPreqs '../modules/azureStackHCIClusterPreqs/ashciPrereqs.bicep' = {
  dependsOn: [
    hciHostDeployment
  ]
  name: 'hciClusterPreqs'
  params: {
    location: 'eastus'
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    arcNodeResourceIds: arcNodeResourceIds
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    deploymentPrefix: deploymentPrefix
    deploymentUsername: deploymentUsername
    deploymentUserPassword: deploymentUsername
    hciResourceProviderObjectId: hciResourceProviderObjectId
    keyVaultName: keyVaultName
    localAdminPassword: localAdminPassword
    localAdminUsername: localAdminUsername
    logsRetentionInDays: logsRetentionInDays
    softDeleteRetentionDays: softDeleteRetentionDays
    tenantId: tenantId
  }
}
