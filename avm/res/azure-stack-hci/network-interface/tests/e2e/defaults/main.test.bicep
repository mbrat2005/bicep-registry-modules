targetScope = 'subscription'

metadata name = 'Using default config'
metadata description = 'This instance deploys the module with the minimum set of required parameters.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
// e.g., for a module 'network/private-endpoint' you could use 'dep-dev-network.privateendpoints-${serviceShort}-rg'
param resourceGroupName string = 'dep-${namePrefix}-azurestackhci-networkinterface-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param resourceLocation string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
// e.g., for a module 'network/private-endpoint' you could use 'npe' as a prefix and then 'waf' as a suffix for the waf-aligned test
param serviceShort string = 'asnicmin'

@description('Optional. A token to inject into the name of each resource. This value can be automatically injected by the CI.')
param namePrefix string = 'avm5'

@description('Required. The app ID of the service principal used for the Azure Stack HCI Resource Bridge deployment. If omitted, the deploying user must have permissions to create service principals and role assignments in Entra ID.')
param arbDeploymentAppId string = '#_AZURESTACKHCI_AZURESTACKHCIAPPID_#'

@description('Required. The service principal ID of the service principal used for the Azure Stack HCI Resource Bridge deployment. If omitted, the deploying user must have permissions to create service principals and role assignments in Entra ID.')
param arbDeploymentSPObjectId string = '#_AZURESTACKHCI_AZURESTACKHCISPOBJECTID_#'

@description('Required. The secret of the service principal used for the Azure Stack HCI Resource Bridge deployment. If omitted, the deploying user must have permissions to create service principals and role assignments in Entra ID.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentServicePrincipalSecret string = '#_AZURESTACKHCI_AZURESTACKHCISPSECRET_#'

@description('Optional. The service principal ID of the Azure Stack HCI Resource Provider. If this is not provided, the module attemps to determine this value by querying the Microsoft Graph.')
param hciResourceProviderObjectId string = '#_AZURESTACKHCI_AZURESTACKHCIRESOURCEPROVIDERID_#'

@description('Optional. The password to use for the local and domain accounts in the test.')
param localAdminAndDeploymentUserPass string = newGuid()

@description('Optional. The subnet ID of an existing subnet in the same location. KeyVault and Storage service endpoints must be enabled!. If not provided, a new VNET is created.')
param vnetSubnetId string?

// ============ //
// Dependencies //
// ============ //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: resourceLocation
}

module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-nestedDependencies'
  params: {
    location: resourceLocation
    hciResourceProviderObjectId: hciResourceProviderObjectId
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    localAdminAndDeploymentUserPass: localAdminAndDeploymentUserPass
    vnetSubnetId: vnetSubnetId
  }
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
      // You parameters go here
      name: '${namePrefix}${serviceShort}001'
      location: resourceLocation
      customLocation: nestedDependencies.outputs.customLocationId
      ipConfigurations: [
        {
          name: 'ipConfig1'
          properties: {
            subnet: {
              id: nestedDependencies.outputs.subnetId
            }
          }
        }
      ]
    }
  }
]
