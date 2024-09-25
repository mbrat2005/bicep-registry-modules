targetScope = 'subscription'

metadata name = 'WAF-aligned'
metadata description = 'This instance deploys the module in alignment with the best-practices of the Azure Well-Architected Framework.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-dev-ops-infrastructure.pool-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param resourceLocation string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'mdpwaf'

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '#_namePrefix_#'

@description('Required. Name of the Azure DevOps Organization. This value is tenant-specific and must be stored in the CI Key Vault in a secret named \'CI-AzureDevOpsOrganizationName\'.')
@secure()
param azureDevOpsOrganizationName string = ''

@description('Required. Name of the Azure DevOps WAF Project. This value is tenant-specific and must be stored in the CI Key Vault in a secret named \'CI-AzureDevOpsProjectName\'.')
@secure()
param azureDevOpsProjectName string = ''

@description('Required. The object ID of the Entra ID-provided DevOpsInfrastructure principal. This value is tenant-specific and must be stored in the CI Key Vault in a secret named \'CI-DevOpsInfrastructureObjectID\'.')
@secure()
param devOpsInfrastructureObjectID string = ''

// ============ //
// Dependencies //
// ============ //
module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-nestedDependencies'
  params: {
    devCenterName: 'dep-${namePrefix}-dc-${serviceShort}'
    devCenterProjectName: 'dep-${namePrefix}-dcp-${serviceShort}'
    managedIdentityName: 'dep-${namePrefix}-msi-${serviceShort}'
    virtualNetworkName: 'dep-${namePrefix}-vnet-${serviceShort}'
    devOpsInfrastructureObjectID: devOpsInfrastructureObjectID
  }
}

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: resourceLocation
}

// ============== //
// Test Execution //
// ============== //

@batchSize(1)
module testDeployment '../../../main.bicep' = [
  for iteration in ['init', 'idem']: {
    scope: resourceGroup
    name: '${uniqueString(deployment().name, resourceLocation)}-test-${serviceShort}-${iteration}'
    params: {
      name: '${namePrefix}${serviceShort}001'
      location: resourceLocation
      agentProfile: {
        kind: 'Stateless'
        resourcePredictions: {
          timeZone: 'Central Europe Standard Time'
          daysData: [
            // Monday
            {
              '09:00:00': 1
              '17:00:00': 0
            }
            // Tuesday
            {}
            // Wednesday
            {}
            // Thursday
            {}
            // Friday
            {
              '09:00:00': 1
              '17:00:00': 0
            }
            // Saturday
            {}
            // Sunday
            {}
          ]
        }
        resourcePredictionsProfile: {
          kind: 'Automatic'
          predictionPreference: 'Balanced'
        }
      }
      concurrency: 1
      devCenterProjectResourceId: nestedDependencies.outputs.devCenterProjectResourceId
      images: [
        {
          wellKnownImageName: 'windows-2022/latest'
        }
      ]
      fabricProfileSkuName: 'Standard_D2_v2'
      subnetResourceId: nestedDependencies.outputs.subnetResourceId
      organizationProfile: {
        kind: 'AzureDevOps'
        organizations: [
          {
            url: 'https://dev.azure.com/${azureDevOpsOrganizationName}'
            projects: [
              azureDevOpsProjectName
            ]
            parallelism: 1
          }
        ]
        permissionProfile: {
          kind: 'CreatorOnly'
        }
      }
    }
  }
]