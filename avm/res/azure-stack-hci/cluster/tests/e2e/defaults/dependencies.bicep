@minLength(4)
@maxLength(8)
param deploymentPrefix string
param deploymentUsername string
@secure()
param deploymentUserPassword string
param localAdminUsername string
@secure()
param localAdminPassword string
param arbDeploymentAppId string
param arbDeploymentSPObjectId string
@secure()
param arbDeploymentServicePrincipalSecret string
param hciResourceProviderObjectId string
param clusterNodeNames array
param softDeleteRetentionDays int = 30
@minValue(0)
@maxValue(365)
param logsRetentionInDays int = 30

var arcNodeResourceIds = [
  for (nodeName, index) in clusterNodeNames: resourceId('Microsoft.HybridCompute/machines', nodeName)
]

var clusterWitnessStorageAccountName = '${deploymentPrefix}witness'
var keyVaultName = 'kvhci-${deploymentPrefix}'
var tenantId = subscription().tenantId

module hciHostDeployment '../../modules/azureStackHCIHost/hciHostDeployment.bicep' = {
  name: 'hciHostDeployment'
  params: {
    location: 'eastus'
    localAdminPassword: localAdminPassword
  }
}

module hciClusterPreqs '../../modules/azureStackHCIClusterPreqs/ashciPrereqs.bicep' = {
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
    deploymentUserPassword: deploymentUserPassword
    hciResourceProviderObjectId: hciResourceProviderObjectId
    keyVaultName: keyVaultName
    localAdminPassword: localAdminPassword
    localAdminUsername: localAdminUsername
    logsRetentionInDays: logsRetentionInDays
    softDeleteRetentionDays: softDeleteRetentionDays
    tenantId: tenantId
  }
}
