metadata name = 'Azure Stack HCI Cluster'
metadata description = 'This module deploys an Azure Stack HCI Cluster.'
metadata owner = 'Azure/module-maintainers'

@description('Required. Name of the Azure Stack HCI Cluster.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@sys.description('Optional. Tags of the resource.')
param tags object?

@description('First must pass with this parameter set to Validate prior running with it set to Deploy. If either Validation or Deployment phases fail, fix the issue, then resubmit the template with the same deploymentMode to retry.')
@allowed([
  'Validate'
  'Deploy'
])
param deploymentMode string = 'Validate'

@description('The prefix for the resource for the deployment. This value is used in key vault and storage account names in this template, as well as for the deploymentSettings.properties.deploymentConfiguration.scaleUnits.deploymentData.namingPrefix property which requires regex pattern: ^[a-zA-Z0-9-]{1,8}$')
@minLength(4)
@maxLength(8)
param deploymentPrefix string

// credentials for the deployment and ongoing lifecycle management
@description('The deployment username for the deployment - this is the user created in Active Directory by the preparation script')
param deploymentUsername string

@description('The deployment password for the deployment - this is for the user created in Active Directory by the preparation script')
@secure()
param deploymentUserPassword string

@description('The local admin username for the deployment - this is the local admin user for the nodes in the deployment - ex "deployuser"')
param localAdminUsername string

@description('The local admin password for the deployment - this is the local admin user for the nodes in the deployment')
@secure()
param localAdminPassword string

@description('The application ID of the pre-created App Registration for the Arc Resource Bridge deployment')
param arbDeploymentAppId string

@description('The service principal object ID of the pre-created App Registration for the Arc Resource Bridge deployment')
param arbDeploymentSPObjectId string

@description('A client secret of the pre-created App Registration for the Arc Resource Bridge deployment')
@secure()
param arbDeploymentServicePrincipalSecret string

@description('Entra ID object ID of the Azure Stack HCI Resource Provider in your tenant - to get, run `Get-AzADServicePrincipal -ApplicationId 1412d89f-b8a8-4111-b4fd-e82905cbd85d`')
param hciResourceProviderObjectId string

// cluster and active directory settings
@description('The name of the Azure Stack HCI cluster - this must be a valid Active Directory computer name and will be the name of your cluster in Azure.')
@maxLength(15)
@minLength(4)
param clusterName string

@description('Names of the cluster node Arc Machine resources - ex "hci-node-1, hci-node-2"')
param clusterNodeNames array

@description('The domain name of the Active Directory Domain Services - ex "contoso.com"')
param domainFqdn string

@description('The ADDS OU path - ex "OU=HCI,DC=contoso,DC=com"')
param domainOUPath string

// retention policy for the Azure Key Vault and Key Vault diagnostics
param softDeleteRetentionDays int = 30

@description('Specifies the number of days that logs will be kept. If you do not want to apply any retention policy and retain data forever, set value to 0.')
@minValue(0)
@maxValue(365)
param logsRetentionInDays int = 30

@description('Security configuration settings object')
param securityConfiguration securityConfigurationType = {
  hvciProtection: true
  drtmProtection: true
  driftControlEnforced: true
  credentialGuardEnforced: true
  smbSigningEnforced: true
  smbClusterEncryption: true
  sideChannelMitigationEnforced: true
  bitlockerBootVolume: true
  bitlockerDataVolumes: true
  wdacEnforced: true
}

// cluster diagnostics and telemetry configuration
@description('The metrics data for deploying a hci cluster')
param streamingDataClient bool = true

@description('The location data for deploying a hci cluster')
param isEuropeanUnionLocation bool = false

@description('The diagnostic data for deploying a hci cluster')
param episodicDataUpload bool = true

// storage configuration
@description('The storage volume configuration mode')
@allowed([
  'Express'
  'InfraOnly'
  'KeepStorage'
])
param storageConfigurationMode string = 'Express'

// cluster network configuration details
@description('The subnet mask for deploying a HCI cluster - ex: 255.255.252.0')
param subnetMask string

@description('The default gateway for deploying a HCI cluster')
param defaultGateway string

@description('The starting IP address for the Infrastructure Network IP pool. There must be at least 6 IPs between startingIPAddress and endingIPAddress and this pool should be not include the node IPs')
param startingIPAddress string

@description('The ending IP address for the Infrastructure Network IP pool. There must be at least 6 IPs between startingIPAddress and endingIPAddress and this pool should be not include the node IPs')
param endingIPAddress string

@description('The DNS servers for deploying a HCI cluster')
param dnsServers array

param networkIntents networkIntent[]

// define network intent for the cluster
@description('The storage connectivity switchless value for deploying a HCI cluster (less common)')
param storageConnectivitySwitchless bool

@description('The enable storage auto IP value for deploying a HCI cluster - this should be true for most deployments except when deploying a three-node switchless cluster, in which case storage IPs should be configured before deployment and this value set to false')
param enableStorageAutoIp bool = true

@description('An array of JSON objects that define the storage network configuration for the cluster. Each object should contain the adapterName and vlan properties.')
param storageNetworks storageNetworksArrayType

var clusterWitnessStorageAccountName = '${deploymentPrefix}witness'

var keyVaultName = 'kvhci-${deploymentPrefix}'

var customLocationName = '${deploymentPrefix}_cl'

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

resource avmTelemetry 'Microsoft.Resources/deployments@2023-07-01' = if (enableTelemetry) {
  name: take(
    '46d3xbcp.res.azurestackhci-cluster.${replace('-..--..-', '.', '-')}.${substring(uniqueString(deployment().name, location), 0, 4)}',
    64
  )
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

resource cluster 'Microsoft.AzureStackHCI/clusters@2024-02-15-preview' = if (deploymentMode == 'Validate') {
  name: clusterName
  identity: {
    type: 'SystemAssigned'
  }
  location: location
  properties: {}
}

module deploymentSetting 'deployment-settings/main.bicep' = {
  name: 'deploymentSettings'
  params: {
    clusterName: clusterName
    clusterNodeNames: clusterNodeNames
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    customLocationName: customLocationName
    defaultGateway: defaultGateway
    deploymentMode: deploymentMode
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    enableStorageAutoIp: enableStorageAutoIp
    endingIPAddress: endingIPAddress
    episodicDataUpload: episodicDataUpload
    isEuropeanUnionLocation: isEuropeanUnionLocation
    keyVaultName: keyVaultName
    networkIntents: networkIntents
    securityConfiguration: securityConfiguration
    startingIPAddress: startingIPAddress
    storageConfigurationMode: storageConfigurationMode
    storageConnectivitySwitchless: storageConnectivitySwitchless
    storageNetworks: storageNetworks
    streamingDataClient: streamingDataClient
    subnetMask: subnetMask
  }
}

type networkIntent = {
  adapter: string[]
  name: string
  overrideAdapterProperty: bool
  adapterPropertyOverrides: {
    jumboPacket: string
    networkDirect: string
    networkDirectTechnology: string
  }
  overrideQosPolicy: bool
  qosPolicyOverrides: {
    bandwidthPercentage_SMB: string
    priorityValue8021Action_Cluster: string
    priorityValue8021Action_SMB: string
  }
  overrideVirtualSwitchConfiguration: bool
  virtualSwitchConfigurationOverrides: {
    enableIov: string
    loadBalancingAlgorithm: string
  }
  trafficType: string[]
}

// define custom type for storage adapter IP info for 3-node switchless deployments
type storageAdapterIPInfoType = {
  physicalNode: string
  ipv4Address: string
  subnetMask: string
}

// define custom type for storage network objects
type storageNetworksType = {
  adapterName: string
  vlan: string
  storageAdapterIPInfo: storageAdapterIPInfoType[]? // optional for non-switchless deployments
}
type storageNetworksArrayType = storageNetworksType[]

// cluster security configuration settings
type securityConfigurationType = {
  hvciProtection: bool
  drtmProtection: bool
  driftControlEnforced: bool
  credentialGuardEnforced: bool
  smbSigningEnforced: bool
  smbClusterEncryption: bool
  sideChannelMitigationEnforced: bool
  bitlockerBootVolume: bool
  bitlockerDataVolumes: bool
  wdacEnforced: bool
}
