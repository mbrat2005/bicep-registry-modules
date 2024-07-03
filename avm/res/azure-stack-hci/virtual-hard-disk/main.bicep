metadata name = 'Azure Stack HCI Virtual Hard Disk'
metadata description = 'This module deploys an Azure Stack HCI Virtual Hard Disk.'
metadata owner = 'Azure/module-maintainers'

@description('Required. Name of the resource to create.')
param name string

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the resource.')
param tags object?

@description('Required. Resource ID of the associated custom location.')
param customLocation string

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Optional. The storage path name of the container. If omitted, the disk will be created on any available CSV.')
param storagePathName string?

@description('Required. The size of the disk in GB.')
param diskSizeGB int

@description('Optional. The file format of the disk. Defaults to \'vhdx\'.')
@allowed(['vhdx', 'vhd'])
param diskFileFormat string = 'vhdx'

@description('Optional. The type of the disk. Defaults to \'true\'.')
param dynamic bool = true

@description('Optional. The generation of the Hyper-V virtual machine. Defaults to \'V2\'.')
@allowed(['V1', 'V2'])
param hyperVGeneration string = 'V2'

@description('Optional. The block size of the disk in bytes.')
param blockSizeBytes int?

@description('Optional. The logical sector size of the disk in bytes.')
param logicalSectorBytes int?

@description('Optional. The physical sector size of the disk in bytes.')
param physicalSectorBytes int?

@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType

var builtInRoleNames = {
  // Add other relevant built-in roles here for your resource as per BCPNFR5
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Azure Stack HCI VM Contributor': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '874d1c73-6003-4e60-a13a-cb31ea190a85'
  )
  'Azure Stack HCI VM Reader': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '4b3fe76c-f777-4d24-a2d7-b027b0f7b273'
  )
  'Azure Stack HCI Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'bda0d508-adf1-4af0-9c28-88919fc3ae06'
  )
}

// ============== //
// Resources      //
// ============== //

#disable-next-line no-deployments-resources
resource avmTelemetry 'Microsoft.Resources/deployments@2023-07-01' = if (enableTelemetry) {
  name: '46d3xbcp.res.azurestackhci-virtualharddisk.${replace('-..--..-', '.', '-')}.${substring(uniqueString(deployment().name, location), 0, 4)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        telemetry: {
          type: 'String'
          value: 'For more information, see https://aka.ms/avm/TelemetryInfo'
        }
      }
    }
  }
}

resource virtualHardDisk 'Microsoft.AzureStackHCI/virtualHardDisks@2024-01-01' = {
  name: name
  location: location
  tags: tags
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocation
  }
  properties: {
    blockSizeBytes: blockSizeBytes
    containerId: storagePathName
    diskFileFormat: diskFileFormat
    diskSizeGB: diskSizeGB
    dynamic: dynamic
    hyperVGeneration: hyperVGeneration
    logicalSectorBytes: logicalSectorBytes
    physicalSectorBytes: physicalSectorBytes
  }
}

resource virtualHardDisk_roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (roleAssignment, index) in (roleAssignments ?? []): {
    name: guid(virtualHardDisk.id, roleAssignment.principalId, roleAssignment.roleDefinitionIdOrName)
    properties: {
      roleDefinitionId: contains(builtInRoleNames, roleAssignment.roleDefinitionIdOrName)
        ? builtInRoleNames[roleAssignment.roleDefinitionIdOrName]
        : contains(roleAssignment.roleDefinitionIdOrName, '/providers/Microsoft.Authorization/roleDefinitions/')
            ? roleAssignment.roleDefinitionIdOrName
            : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName)
      principalId: roleAssignment.principalId
      description: roleAssignment.?description
      principalType: roleAssignment.?principalType
      condition: roleAssignment.?condition
      conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
      delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
    }
    scope: virtualHardDisk
  }
]

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the resource.')
output resourceId string = virtualHardDisk.id

@description('The name of the resource.')
output name string = virtualHardDisk.name

@description('The resource group name of the resource.')
output resourceGroupName string = resourceGroup().name

@description('The location the resource was deployed into.')
output location string = virtualHardDisk.location

// ================ //
// Definitions      //
// ================ //
//

type roleAssignmentType = {
  @description('Required. The role to assign. You can provide either the display name of the role definition, the role definition GUID, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
  roleDefinitionIdOrName: string

  @description('Required. The principal ID of the principal (user/group/identity) to assign the role to.')
  principalId: string

  @description('Optional. The principal type of the assigned principal ID.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ForeignGroup' | 'Device')?

  @description('Optional. The description of the role assignment.')
  description: string?

  @description('Optional. The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container".')
  condition: string?

  @description('Optional. Version of the condition.')
  conditionVersion: '2.0'?

  @description('Optional. The Resource Id of the delegated managed identity resource.')
  delegatedManagedIdentityResourceId: string?
}[]?
