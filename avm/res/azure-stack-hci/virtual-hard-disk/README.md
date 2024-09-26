# Azure Stack HCI Virtual Hard Disk `[Microsoft.AzureStackHCI/virtualHardDisks]`

This module deploys an Azure Stack HCI Virtual Hard Disk.

## Navigation

- [Resource Types](#Resource-Types)
- [Usage examples](#Usage-examples)
- [Parameters](#Parameters)
- [Outputs](#Outputs)
- [Data Collection](#Data-Collection)

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.Authorization/roleAssignments` | [2022-04-01](https://learn.microsoft.com/en-us/azure/templates/Microsoft.Authorization/2022-04-01/roleAssignments) |
| `Microsoft.AzureStackHCI/virtualHardDisks` | [2024-01-01](https://learn.microsoft.com/en-us/azure/templates/Microsoft.AzureStackHCI/virtualHardDisks) |

## Usage examples

The following section provides usage examples for the module, which were used to validate and deploy the module successfully. For a full reference, please review the module's test folder in its repository.

>**Note**: Each example lists all the required parameters first, followed by the rest - each in alphabetical order.

>**Note**: To reference the module, please use the following syntax `br/public:avm/res/azure-stack-hci/virtual-hard-disk:<version>`.

- [Deploy Azure Stack HCI virtual hard disk](#example-1-deploy-azure-stack-hci-virtual-hard-disk)
- [Deploy Azure Stack HCI virtual hard disk WAF aligned](#example-2-deploy-azure-stack-hci-virtual-hard-disk-waf-aligned)

### Example 1: _Deploy Azure Stack HCI virtual hard disk_

Deploy Azure Stack HCI Cluster virutal disk in Azure Stack HCI


<details>

<summary>via Bicep module</summary>

```bicep
module virtualHardDisk 'br/public:avm/res/azure-stack-hci/virtual-hard-disk:<version>' = {
  name: 'virtualHardDiskDeployment'
  params: {
    // Required parameters
    customLocation: '<customLocation>'
    diskSizeGB: '<diskSizeGB>'
    name: 'ashvhdmin001'
    // Non-required parameters
    location: '<location>'
  }
}
```

</details>
<p>

<details>

<summary>via JSON Parameter file</summary>

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    // Required parameters
    "customLocation": {
      "value": "<customLocation>"
    },
    "diskSizeGB": {
      "value": "<diskSizeGB>"
    },
    "name": {
      "value": "ashvhdmin001"
    },
    // Non-required parameters
    "location": {
      "value": "<location>"
    }
  }
}
```

</details>
<p>

### Example 2: _Deploy Azure Stack HCI virtual hard disk WAF aligned_

Deploy Azure Stack HCI Cluster virutal disk in Azure Stack HCI with WAF aligned test


<details>

<summary>via Bicep module</summary>

```bicep
module virtualHardDisk 'br/public:avm/res/azure-stack-hci/virtual-hard-disk:<version>' = {
  name: 'virtualHardDiskDeployment'
  params: {
    // Required parameters
    customLocation: '<customLocation>'
    diskSizeGB: '<diskSizeGB>'
    name: 'ashvhdwaf001'
    // Non-required parameters
    location: '<location>'
  }
}
```

</details>
<p>

<details>

<summary>via JSON Parameter file</summary>

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    // Required parameters
    "customLocation": {
      "value": "<customLocation>"
    },
    "diskSizeGB": {
      "value": "<diskSizeGB>"
    },
    "name": {
      "value": "ashvhdwaf001"
    },
    // Non-required parameters
    "location": {
      "value": "<location>"
    }
  }
}
```

</details>
<p>

## Parameters

**Required parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`customLocation`](#parameter-customlocation) | string | Resource ID of the associated custom location. |
| [`diskSizeGB`](#parameter-disksizegb) | int | The size of the disk in GB. |
| [`name`](#parameter-name) | string | Name of the resource to create. |

**Optional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`blockSizeBytes`](#parameter-blocksizebytes) | int | The block size of the disk in bytes. |
| [`diskFileFormat`](#parameter-diskfileformat) | string | The file format of the disk. Defaults to 'vhdx'. |
| [`dynamic`](#parameter-dynamic) | bool | The type of the disk. Defaults to 'true'. |
| [`enableTelemetry`](#parameter-enabletelemetry) | bool | Enable/Disable usage telemetry for module. |
| [`hyperVGeneration`](#parameter-hypervgeneration) | string | The generation of the Hyper-V virtual machine. Defaults to 'V2'. |
| [`location`](#parameter-location) | string | Location for all Resources. |
| [`logicalSectorBytes`](#parameter-logicalsectorbytes) | int | The logical sector size of the disk in bytes. |
| [`physicalSectorBytes`](#parameter-physicalsectorbytes) | int | The physical sector size of the disk in bytes. |
| [`roleAssignments`](#parameter-roleassignments) | array | Array of role assignments to create. |
| [`storagePathName`](#parameter-storagepathname) | string | The storage path name of the container. If omitted, the disk will be created on any available CSV. |
| [`tags`](#parameter-tags) | object | Tags of the resource. |

### Parameter: `customLocation`

Resource ID of the associated custom location.

- Required: Yes
- Type: string

### Parameter: `diskSizeGB`

The size of the disk in GB.

- Required: Yes
- Type: int

### Parameter: `name`

Name of the resource to create.

- Required: Yes
- Type: string

### Parameter: `blockSizeBytes`

The block size of the disk in bytes.

- Required: No
- Type: int

### Parameter: `diskFileFormat`

The file format of the disk. Defaults to 'vhdx'.

- Required: No
- Type: string
- Default: `'vhdx'`
- Allowed:
  ```Bicep
  [
    'vhd'
    'vhdx'
  ]
  ```

### Parameter: `dynamic`

The type of the disk. Defaults to 'true'.

- Required: No
- Type: bool
- Default: `True`

### Parameter: `enableTelemetry`

Enable/Disable usage telemetry for module.

- Required: No
- Type: bool
- Default: `True`

### Parameter: `hyperVGeneration`

The generation of the Hyper-V virtual machine. Defaults to 'V2'.

- Required: No
- Type: string
- Default: `'V2'`
- Allowed:
  ```Bicep
  [
    'V1'
    'V2'
  ]
  ```

### Parameter: `location`

Location for all Resources.

- Required: No
- Type: string
- Default: `[resourceGroup().location]`

### Parameter: `logicalSectorBytes`

The logical sector size of the disk in bytes.

- Required: No
- Type: int

### Parameter: `physicalSectorBytes`

The physical sector size of the disk in bytes.

- Required: No
- Type: int

### Parameter: `roleAssignments`

Array of role assignments to create.

- Required: No
- Type: array
- Roles configurable by name:
  - `'Contributor'`
  - `'Owner'`
  - `'Reader'`
  - `'Azure Stack HCI VM Contributor'`
  - `'Azure Stack HCI VM Reader'`
  - `'Azure Stack HCI Administrator'`

**Required parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`principalId`](#parameter-roleassignmentsprincipalid) | string | The principal ID of the principal (user/group/identity) to assign the role to. |
| [`roleDefinitionIdOrName`](#parameter-roleassignmentsroledefinitionidorname) | string | The role to assign. You can provide either the display name of the role definition, the role definition GUID, or its fully qualified ID in the following format: '/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11'. |

**Optional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`condition`](#parameter-roleassignmentscondition) | string | The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container". |
| [`conditionVersion`](#parameter-roleassignmentsconditionversion) | string | Version of the condition. |
| [`delegatedManagedIdentityResourceId`](#parameter-roleassignmentsdelegatedmanagedidentityresourceid) | string | The Resource Id of the delegated managed identity resource. |
| [`description`](#parameter-roleassignmentsdescription) | string | The description of the role assignment. |
| [`name`](#parameter-roleassignmentsname) | string | The name (as GUID) of the role assignment. If not provided, a GUID will be generated. |
| [`principalType`](#parameter-roleassignmentsprincipaltype) | string | The principal type of the assigned principal ID. |

### Parameter: `roleAssignments.principalId`

The principal ID of the principal (user/group/identity) to assign the role to.

- Required: Yes
- Type: string

### Parameter: `roleAssignments.roleDefinitionIdOrName`

The role to assign. You can provide either the display name of the role definition, the role definition GUID, or its fully qualified ID in the following format: '/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11'.

- Required: Yes
- Type: string

### Parameter: `roleAssignments.condition`

The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container".

- Required: No
- Type: string

### Parameter: `roleAssignments.conditionVersion`

Version of the condition.

- Required: No
- Type: string
- Allowed:
  ```Bicep
  [
    '2.0'
  ]
  ```

### Parameter: `roleAssignments.delegatedManagedIdentityResourceId`

The Resource Id of the delegated managed identity resource.

- Required: No
- Type: string

### Parameter: `roleAssignments.description`

The description of the role assignment.

- Required: No
- Type: string

### Parameter: `roleAssignments.name`

The name (as GUID) of the role assignment. If not provided, a GUID will be generated.

- Required: No
- Type: string

### Parameter: `roleAssignments.principalType`

The principal type of the assigned principal ID.

- Required: No
- Type: string
- Allowed:
  ```Bicep
  [
    'Device'
    'ForeignGroup'
    'Group'
    'ServicePrincipal'
    'User'
  ]
  ```

### Parameter: `storagePathName`

The storage path name of the container. If omitted, the disk will be created on any available CSV.

- Required: No
- Type: string

### Parameter: `tags`

Tags of the resource.

- Required: No
- Type: object

## Outputs

| Output | Type | Description |
| :-- | :-- | :-- |
| `location` | string | The location the resource was deployed into. |
| `name` | string | The name of the resource. |
| `resourceGroupName` | string | The resource group name of the resource. |
| `resourceId` | string | The resource ID of the resource. |

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the [repository](https://aka.ms/avm/telemetry). There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
