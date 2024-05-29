targetScope = 'subscription'
param name string
@minLength(4)
@maxLength(8)
param deploymentPrefix string = take(uniqueString(deployment().name), 8)
// credentials for the deployment and ongoing lifecycle management
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
param domainFqdn string = 'hci.local'
param domainOUPath string = 'OU=HCI,DC=hci,DC=local'
param subnetMask string = '255.255.255.0'
param defaultGateway string = '172.20.0.1'
param startingIPAddress string = '172.20.0.2'
param endingIPAddress string = '172.20.0.7'
param dnsServers array = ['172.20.0.1']
param networkIntents networkIntent[] = [
  {
    adapter: ['mgmt']
    name: 'management'
    overrideAdapterProperty: false
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Enabled'
      networkDirectTechnology: 'RoCEv2'
    }
    overrideQosPolicy: false
    qosPolicyOverrides: {
      bandwidthPercentage_SMB: '50'
      priorityValue8021Action_Cluster: '7'
      priorityValue8021Action_SMB: '3'
    }
    overrideVirtualSwitchConfiguration: false
    virtualSwitchConfigurationOverrides: {
      enableIov: 'true'
      loadBalancingAlgorithm: 'Dynamic'
    }
    trafficType: ['Management']
  }
  {
    adapter: ['comp0', 'comp1']
    name: 'compute'
    overrideAdapterProperty: false
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Enabled'
      networkDirectTechnology: 'RoCEv2'
    }
    overrideQosPolicy: false
    qosPolicyOverrides: {
      bandwidthPercentage_SMB: '50'
      priorityValue8021Action_Cluster: '7'
      priorityValue8021Action_SMB: '3'
    }
    overrideVirtualSwitchConfiguration: false
    virtualSwitchConfigurationOverrides: {
      enableIov: 'true'
      loadBalancingAlgorithm: 'Dynamic'
    }
    trafficType: ['Compute']
  }
  {
    adapter: ['smb0', 'smb1']
    name: 'storage'
    overrideAdapterProperty: true
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Enabled'
      networkDirectTechnology: 'RoCEv2'
    }
    overrideQosPolicy: true
    qosPolicyOverrides: {
      bandwidthPercentage_SMB: '50'
      priorityValue8021Action_Cluster: '7'
      priorityValue8021Action_SMB: '3'
    }
    overrideVirtualSwitchConfiguration: false
    virtualSwitchConfigurationOverrides: {
      enableIov: 'true'
      loadBalancingAlgorithm: 'Dynamic'
    }
    trafficType: ['Storage']
  }
]

// define network intent for the cluster
param storageConnectivitySwitchless bool = false

param enableStorageAutoIp bool = true

param storageNetworks storageNetworksArrayType = [
  {
    adapterName: 'smb0'
    vlan: '711'
  }
  {
    adapterName: 'smb1'
    vlan: '712'
  }
]
@secure()
param adminPassword string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-hcipipe${deploymentPrefix}'
  location: 'eastus'
}

module hciDependencies './dependencies.bicep' = {
  name: 'hciDependencies'
  scope: resourceGroup
  params: {
    adminPassword: adminPassword
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    clusterNodeNames: clusterNodeNames
    deploymentPrefix: deploymentPrefix
    deploymentUsername: deploymentUsername
    deploymentUserPassword: deploymentUserPassword
    hciResourceProviderObjectId: hciResourceProviderObjectId
    localAdminPassword: localAdminPassword
    localAdminUsername: localAdminUsername
  }
}

module cluster_validate '../../../main.bicep' = {
  dependsOn: [
    hciDependencies
  ]
  name: 'cluster_validate'
  scope: resourceGroup
  params: {
    name: name
    clusterNodeNames: clusterNodeNames
    defaultGateway: defaultGateway
    deploymentMode: 'Validate'
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    endingIPAddress: endingIPAddress
    enableStorageAutoIp: enableStorageAutoIp
    networkIntents: networkIntents
    startingIPAddress: startingIPAddress
    storageConnectivitySwitchless: storageConnectivitySwitchless
    storageNetworks: storageNetworks
    subnetMask: subnetMask
  }
}

module cluster_deploy '../../../main.bicep' = {
  dependsOn: [
    hciDependencies
    cluster_validate
  ]
  name: 'cluster_deploy'
  scope: resourceGroup
  params: {
    name: name
    clusterNodeNames: clusterNodeNames
    defaultGateway: defaultGateway
    deploymentMode: 'Deploy'
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    endingIPAddress: endingIPAddress
    enableStorageAutoIp: enableStorageAutoIp
    networkIntents: networkIntents
    startingIPAddress: startingIPAddress
    storageConnectivitySwitchless: storageConnectivitySwitchless
    storageNetworks: storageNetworks
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
