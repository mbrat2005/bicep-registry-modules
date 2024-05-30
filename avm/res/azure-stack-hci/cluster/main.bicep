metadata name = 'Azure Stack HCI Cluster'
metadata description = 'This module deploys an Azure Stack HCI Cluster.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the Azure Stack HCI cluster - this must be a valid Active Directory computer name and will be the name of your cluster in Azure.')
@maxLength(15)
@minLength(4)
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@sys.description('Optional. Tags of the resource.')
param tags object?

@description('Required. First must pass with this parameter set to Validate prior running with it set to Deploy. If either Validation or Deployment phases fail, fix the issue, then resubmit the template with the same deploymentMode to retry.')
@allowed([
  'Validate'
  'Deploy'
])
param deploymentMode string

@description('Required. The prefix for the resource for the deployment. This value is used in key vault and storage account names in this template, as well as for the deploymentSettings.properties.deploymentConfiguration.scaleUnits.deploymentData.namingPrefix property which requires regex pattern: ^[a-zA-Z0-9-]{1,8}$')
@minLength(4)
@maxLength(8)
param deploymentPrefix string

@description('Required. Names of the cluster node Arc Machine resources. These are the name of the Arc Machine resources created when the new HCI nodes were Arc initialized. Example: [hci-node-1, hci-node-2]')
param clusterNodeNames array

@description('Required. The domain name of the Active Directory Domain Services. Example: "contoso.com"')
param domainFqdn string

@description('Required. The ADDS OU path - ex "OU=HCI,DC=contoso,DC=com"')
param domainOUPath string

@description('Optional. Security configuration settings object; defaults to most secure posture.')
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
@description('Optional. The metrics data for deploying a HCI cluster')
param streamingDataClient bool = true

@description('Optional. The location data for deploying a HCI cluster')
param isEuropeanUnionLocation bool = false

@description('Optional. The diagnostic data for deploying a HCI cluster')
param episodicDataUpload bool = true

// storage configuration
@description('Optional. The storage volume configuration mode. See documentation for details.')
@allowed([
  'Express'
  'InfraOnly'
  'KeepStorage'
])
param storageConfigurationMode string = 'Express'

// cluster network configuration details
@description('Required. The subnet mask pf the Management Network for the HCI cluster - ex: 255.255.252.0')
param subnetMask string

@description('Required. The default gateway of the Management Network. Exameple: 192.168.0.1')
param defaultGateway string

@description('Required. The starting IP address for the Infrastructure Network IP pool. There must be at least 6 IPs between startingIPAddress and endingIPAddress and this pool should be not include the node IPs')
param startingIPAddress string

@description('Required. The ending IP address for the Infrastructure Network IP pool. There must be at least 6 IPs between startingIPAddress and endingIPAddress and this pool should be not include the node IPs')
param endingIPAddress string

@description('Required. The DNS servers accessible from the Management Network for the HCI cluster')
param dnsServers array

@description('Required. An array of Network ATC Network Intent objects that define the Compute, Management, and Storage network configuration for the cluster.')
param networkIntents networkIntent[]

// define network intent for the cluster
@description('Required. Specify whether the Storage Network connectivity is switched or switchless.')
param storageConnectivitySwitchless bool

@description('Required. Enable storage auto IP assignment. This should be true for most deployments except when deploying a three-node switchless cluster, in which case storage IPs should be configured before deployment and this value set to false')
param enableStorageAutoIp bool = true

@description('Required. An array of JSON objects that define the storage network configuration for the cluster. Each object should contain the adapterName, VLAN properties, and (optionally) IP configurations.')
param storageNetworks storageNetworksArrayType

@description('Required. The name of the Custom Location associated with the Arc Resource Bridge for this cluster. This value should reflect the physical location and identifier of the HCI cluster. Example: cl-hci-den-clu01')
param customLocationName string = '${deploymentPrefix}_cl'

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Optional. The name of the storage account to be used as the witness for the HCI Windows Failover Cluster.')
param clusterWitnessStorageAccountName string = '${deploymentPrefix}witness'

@description('Optional. The name of the key vault to be used for storing secrets for the HCI cluster. This currently needs to be unique per HCI cluster.')
param keyVaultName string = 'kvhci-${deploymentPrefix}'

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
  name: name
  identity: {
    type: 'SystemAssigned'
  }
  location: location
  properties: {}
  tags: tags
}

module deploymentSetting 'deployment-settings/main.bicep' = {
  name: 'deploymentSettings'
  params: {
    clusterName: name
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

output name string = cluster.name
output resourceId string = cluster.id
output systemAssignedMIPrincipalId string = cluster.identity.principalId

type networkIntent = {
  @description('Required. The names of the network adapters to include in the intent.')
  adapter: string[]
  @description('Required. The name of the network intent.')
  name: string
  @description('Required. Specify whether to override the adapter property. Use false by default.')
  overrideAdapterProperty: bool
  adapterPropertyOverrides: {
    @description('Required. The jumboPacket configuration for the network adapters.')
    jumboPacket: string
    @description('Required. The networkDirect configuration for the network adapters. Allowed values: "Enabled", "Disabled"')
    networkDirect: string
    @description('Required. The networkDirectTechnology configuration for the network adapters. Allowed values: "RoCEv2", "iWARP"')
    networkDirectTechnology: string
  }
  @description('Required. Specify whether to override the qosPolicy property. Use false by default.')
  overrideQosPolicy: bool
  qosPolicyOverrides: {
    @description('Required. The bandwidthPercentage for the network intent. Recommend 50.')
    bandwidthPercentage_SMB: string
    @description('Required. Recommend 7')
    priorityValue8021Action_Cluster: string
    @description('Required. Recommend 3')
    priorityValue8021Action_SMB: string
  }
  @description('Required. Specify whether to override the virtualSwitchConfiguration property. Use false by default.')
  overrideVirtualSwitchConfiguration: bool
  virtualSwitchConfigurationOverrides: {
    @description('Required. The enableIov configuration for the network intent. Allowed values: "True", "False"')
    enableIov: string
    @description('Required. The loadBalancingAlgorithm configuration for the network intent. Allowed values: "Dynamic", "HyperVPort", "IPHash"')
    loadBalancingAlgorithm: string
  }
  @description('Required. The traffic types for the network intent. Allowed values: "Compute", "Management", "Storage"')
  trafficType: string[]
}

// define custom type for storage adapter IP info for 3-node switchless deployments
type storageAdapterIPInfoType = {
  @description('Required. The HCI node name.')
  physicalNode: string
  @description('Required. The IPv4 address for the storage adapter.')
  ipv4Address: string
  @description('Required. The subnet mask for the storage adapter.')
  subnetMask: string
}

// define custom type for storage network objects
type storageNetworksType = {
  @description('Required. The name of the storage adapter.')
  adapterName: string
  @description('Required. The VLAN for the storage adapter.')
  vlan: string
  @description('Optional. The storage adapter IP information for 3-node switchless or manual config deployments.')
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
