# Arc Gateway `[Microsoft.AzureStackHCI/clusters]`

This module deploys an Arc Gateway.

## Navigation

- [Resource Types](#Resource-Types)
- [Parameters](#Parameters)
- [Outputs](#Outputs)
- [Cross-referenced modules](#Cross-referenced-modules)
- [Data Collection](#Data-Collection)

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.HybridCompute/gateways` | [2024-05-20-preview](https://learn.microsoft.com/en-us/azure/templates) |

## Parameters

**Required parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`name`](#parameter-name) | string | The name of the Arc Gateway to deploy. |

**Optional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`allowedFeatures`](#parameter-allowedfeatures) | array | Arc Gateway allowed features. |
| [`gatewayType`](#parameter-gatewaytype) | string | Arc Gateway type. Detaults to Public. |
| [`location`](#parameter-location) | string | Location for all resources. |
| [`tags`](#parameter-tags) | object | Tags of the resource. |

### Parameter: `name`

The name of the Arc Gateway to deploy.

- Required: Yes
- Type: string

### Parameter: `allowedFeatures`

Arc Gateway allowed features.

- Required: No
- Type: array
- Default:
  ```Bicep
  [
    '*'
  ]
  ```

### Parameter: `gatewayType`

Arc Gateway type. Detaults to Public.

- Required: No
- Type: string
- Default: `'Public'`
- Allowed:
  ```Bicep
  [
    'Public'
  ]
  ```

### Parameter: `location`

Location for all resources.

- Required: No
- Type: string
- Default: `[resourceGroup().location]`

### Parameter: `tags`

Tags of the resource.

- Required: No
- Type: object


## Outputs

| Output | Type | Description |
| :-- | :-- | :-- |
| `location` | string | The location of the arcGateway. |
| `name` | string | The name of the Arc Gateway. |
| `resourceGroupName` | string | The resource group of the Arc Gateway. |
| `resourceId` | string | The ID of the Arc Gateway. |

## Cross-referenced modules

_None_

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the [repository](https://aka.ms/avm/telemetry). There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
