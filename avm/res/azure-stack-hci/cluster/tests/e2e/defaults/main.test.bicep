metadata name = 'Deploy Azure Stack HCI Cluster in Azure with a 2 node switched configuration'
metadata description = 'This test deploys an Azure VM to host a 2 node switched Azure Stack HCI cluster, validates the cluster configuration, and then deploys the cluster.'

targetScope = 'subscription'
param name string = 'hcicluster'
@minLength(4)
@maxLength(8)
param location string = 'eastus'
param resourceGroupName string = 'dep-azure-stack-hci.cluster-${serviceShort}-rg'
param serviceShort string = 'ashcdef'
param deploymentPrefix string = take(uniqueString(deployment().name), 8)
// credentials for the deployment and ongoing lifecycle management
param deploymentUsername string = 'deployUser'
@secure()
param deploymentUserPassword string = newGuid()
param localAdminUsername string = 'admin-hci'
@secure()
param localAdminPassword string = newGuid()
param arbDeploymentAppId string
param arbDeploymentSPObjectId string
@secure()
param arbDeploymentServicePrincipalSecret string
param clusterNodeNames array = ['hcinode1', 'hcinode2']
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

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module hciDependencies './dependencies.bicep' = {
  name: 'hciDependencies'
  scope: resourceGroup
  params: {
    clusterNodeNames: clusterNodeNames
    deploymentPrefix: deploymentPrefix
    deploymentUsername: deploymentUsername
    deploymentUserPassword: deploymentUserPassword
    localAdminPassword: localAdminPassword
    localAdminUsername: localAdminUsername
    location: location
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
  }
}

module cluster_validate '../../../main.bicep' = {
  dependsOn: [
    hciDependencies
  ]
  name: '${uniqueString(deployment().name, location)}-test_clustervalidate-${serviceShort}'
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

module testDeployment '../../../main.bicep' = {
  dependsOn: [
    hciDependencies
    cluster_validate
  ]
  name: '${uniqueString(deployment().name, location)}-test_clusterdeploy-${serviceShort}'
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
