targetScope = 'subscription'

metadata name = 'Creates an Arc Machine with maximum configurations'
metadata description = 'This instance deploys the module with the full set of required parameters.'

// ========== //
// Parameters //
// ========== //

@description('Required. The kind of machine to deploy.')
param kind string = 'HCI'

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-hybridCompute.machine-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param resourceLocation string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'arcmacmin'

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '#_namePrefix_#'

// ============ //
// Dependencies //
// ============ //

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
      location: resourceLocation
      name: '${namePrefix}${serviceShort}'
      kind: kind
      configurationProfile: 'providers/Microsoft.Automanage/bestPractices/AzureBestPracticesDevTest'
      extensionAntiMalwareConfig: {
        enabled: true
      }
      extensionDSCConfig: {
        enabled: true
        configurationMode: 'ApplyAndMonitor'
        configurationModeFrequencyMins: 15
        refreshFrequencyMins: 30
        rebootNodeIfNeeded: true
        actionAfterReboot: 'ContinueConfiguration'
        nodeConfigurationName: 'MyDSCConfig'
        configurationArguments: {}
      }
      extensionCustomScriptConfig: {
        script: 'echo "Hello World"'
      }
      extensionCustomScriptProtectedSetting: {}
      extensionDependencyAgentConfig: {
        enabled: true
      }
      extensionGuestConfigurationExtension: {
        enabled: true
      }
      extensionGuestConfigurationExtensionProtectedSettings: {}
      extensionMonitoringAgentConfig: {
        enabled: true
      }
      guestConfiguration: {
        name: 'AzureWindowsBaseline'
        version: '1.*'
        assignmentType: 'ApplyAndMonitor'
        configurationParameter: [
          {
            name: 'Minimum Password Length;ExpectedValue'
            value: '16'
          }
          {
            name: 'Minimum Password Length;RemediateValue'
            value: '16'
          }
          {
            name: 'Maximum Password Age;ExpectedValue'
            value: '75'
          }
          {
            name: 'Maximum Password Age;RemediateValue'
            value: '75'
          }
        ]
      }
      osType: 'Windows'
      sasTokenValidityLength: 'PT1H'
    }
  }
]