metadata name = 'Arc Gateway'
metadata description = 'This module deploys an Arc Gateway.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the Arc Gateway to deploy')
@maxLength(15)
@minLength(4)
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the resource.')
param tags object?

@description('Arc Gateway allowed features')
param allowedFeatures array = ['*']

@description('Arc Gateway type')
@allowed(['Public'])
param gatewayType string = 'Public'

resource arcGateway 'Microsoft.HybridCompute/gateways@2024-03-31-preview' = {
  location: location
  name: name
  properties: {
    allowedFeatures: allowedFeatures
    gatewayType: gatewayType
  }
}

@description('The name of the Arc Gateway.')
output name string = arcGateway.name
@description('The ID of the Arc Gateway.')
output resourceId string = arcGateway.id
@description('The resource group of the Arc Gateway.')
output resourceGroupName string = resourceGroup().name
@description('The location of the arcGateway.')
output location string = arcGateway.location
