metadata name = 'Deploy Azure Stack HCI Cluster in Azure with a 1 node configuration'
metadata description = 'Deploy Azure Stack HCI Cluster in Azure with a 1 node configuration then create a Logical Network with a subnet and IP configuration.'

@description('Optional. The name of the Azure Stack HCI cluster - this must be a valid Active Directory computer name and will be the name of your cluster in Azure.')
@maxLength(15)
@minLength(4)
param name string = 'hcicluster'
@description('Optional. Location for all resources.')
param location string
@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'ashvdwaf'
@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '#_namePrefix_#'
@minLength(4)
@maxLength(8)
@description('Optional. The prefix for the resource for the deployment. This value is used in key vault and storage account names in this template, as well as for the deploymentSettings.properties.deploymentConfiguration.scaleUnits.deploymentData.namingPrefix property which requires regex pattern: ^[a-zA-Z0-9-]{1,8}$.')
param deploymentPrefix string = take('${take(namePrefix, 8)}${uniqueString(utcNow())}', 8)
@description('Optional. The username of the LCM deployment user created in Active Directory.')
param deploymentUsername string = 'deployUser'
@description('Optional. The password of the LCM deployment user and local administrator accounts.')
@secure()
param localAdminAndDeploymentUserPass string = newGuid()
@description('Optional. The username of the local administrator account created on the host VM and each node in the cluster.')
param localAdminUsername string = 'admin-hci'
@description('Required. The app ID of the service principal used for the Azure Stack HCI Resource Bridge deployment. If omitted, the deploying user must have permissions to create service principals and role assignments in Entra ID.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentAppId string = ''
@description('Required. The service principal ID of the service principal used for the Azure Stack HCI Resource Bridge deployment. If omitted, the deploying user must have permissions to create service principals and role assignments in Entra ID.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentSPObjectId string = ''
@description('Optional. The service principal ID of the Azure Stack HCI Resource Provider. If this is not provided, the module attemps to determine this value by querying the Microsoft Graph.')
@secure()
#disable-next-line secure-parameter-default
param hciResourceProviderObjectId string = ''
@description('Required. The secret of the service principal used for the Azure Stack HCI Resource Bridge deployment. If omitted, the deploying user must have permissions to create service principals and role assignments in Entra ID.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentServicePrincipalSecret string = ''
@description('Optional. Array of cluster node names.')
param clusterNodeNames string[] = ['hcinode1']
@description('Optional. The fully qualified domain name of the Active Directory domain.')
param domainFqdn string = 'hci.local'
@description('Optional. The organizational unit path in Active Directory where the cluster computer objects will be created.')
param domainOUPath string = 'OU=HCI,DC=hci,DC=local'
@description('Optional. The subnet mask for the cluster network.')
param subnetMask string = '255.255.255.0'
@description('Optional. The default gateway for the cluster network.')
param defaultGateway string = '172.20.0.1'
@description('Optional. The starting IP address for the cluster network.')
param startingIPAddress string = '172.20.0.2'
@description('Optional. The ending IP address for the cluster network.')
param endingIPAddress string = '172.20.0.7'
@description('Optional. The DNS servers for the cluster network.')
param dnsServers array = ['172.20.0.1']
@description('Optional. The ID of the subnet in the VNet where the cluster will be deployed. If omitted, a new VNET will be deployed.')
param vnetSubnetId string = ''
@description('Optional. The name of the location for the custom location.')
param customLocationName string = '${serviceShort}-location'
@description('Conditional. The URL to download the Azure Stack HCI ISO. Required if hciVHDXDownloadURL is not supplied.')
param hciISODownloadURL string = 'https://azurestackreleases.download.prss.microsoft.com/dbazure/AzureStackHCI/OS-Composition/10.2408.0.3061/AZURESTACKHci23H2.25398.469.LCM.10.2408.0.3061.x64.en-us.iso'
@description('Conditional. The URL to download the Azure Stack HCI VHDX. Required if hciISODownloadURL is not supplied.')
param hciVHDXDownloadURL string = ''
@description('Optional. The network intents for the cluster.')
param networkIntents networkIntent[] = [
  {
    adapter: ['mgmt']
    name: 'management'
    overrideAdapterProperty: true
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Disabled'
      networkDirectTechnology: 'iWARP'
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
    overrideAdapterProperty: true
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Disabled'
      networkDirectTechnology: 'iWARP'
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
      networkDirect: 'Disabled'
      networkDirectTechnology: 'iWARP'
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
@description('Optional. The storage networks for the cluster.')
param storageNetworks storageNetworksArrayType = [
  {
    adapterName: 'smb0'
    vlan: '711'
    storageAdapterIPInfo: [
      {
        //switch A
        physicalNode: 'hcinode1'
        ipv4Address: '10.71.1.1'
        subnetMask: '255.255.255.0'
      }
      {
        //switch A
        physicalNode: 'hcinode2'
        ipv4Address: '10.71.1.2'
        subnetMask: '255.255.255.0'
      }
      {
        // switch B
        physicalNode: 'hcinode3'
        ipv4Address: '10.71.2.3'
        subnetMask: '255.255.255.0'
      }
    ]
  }
  {
    adapterName: 'smb1'
    vlan: '711'
    storageAdapterIPInfo: [
      {
        // switch B
        physicalNode: 'hcinode1'
        ipv4Address: '10.71.2.1'
        subnetMask: '255.255.255.0'
      }
      {
        // switch C
        physicalNode: 'hcinode2'
        ipv4Address: '10.71.3.2'
        subnetMask: '255.255.255.0'
      }
      {
        //switch C
        physicalNode: 'hcinode3'
        ipv4Address: '10.71.3.3'
        subnetMask: '255.255.255.0'
      }
    ]
  }
]

var clusterWitnessStorageAccountName = take(
  '${deploymentPrefix}${serviceShort}${take(uniqueString(resourceGroup().id,resourceGroup().location),6)}wit',
  24
)
var keyVaultDiagnosticStorageAccountName = take(
  '${deploymentPrefix}${serviceShort}${take(uniqueString(resourceGroup().id,resourceGroup().location),6)}kvd',
  24
)
var keyVaultName = 'kvhci-${deploymentPrefix}${take(uniqueString(resourceGroup().id,resourceGroup().location),6)}'

var arcNodeResourceIds = [
  for (nodeName, index) in clusterNodeNames: resourceId('Microsoft.HybridCompute/machines', nodeName)
]

var tenantId = subscription().tenantId

module hciHostDeployment '../../../../../../utilities/e2e-template-assets/templates/azure-stack-hci/modules/azureStackHCIHost/hciHostDeployment.bicep' = {
  name: 'hciHostDeployment-${location}-${deploymentPrefix}'
  params: {
    hciISODownloadURL: hciISODownloadURL
    hciNodeCount: length(clusterNodeNames)
    hciVHDXDownloadURL: hciVHDXDownloadURL
    hciHostAssignPublicIp: true
    localAdminPassword: localAdminAndDeploymentUserPass
    location: location
    vnetSubnetID: vnetSubnetId
    hostVMSize: 'Standard_E8bds_v5'
  }
}

// module microsoftGraphResources '../../../../../../utilities/e2e-template-assets/templates/azure-stack-hci/modules/microsoftGraphResources/main.bicep' = if (empty(hciResourceProviderObjectId)) {
//   name: '${uniqueString(deployment().name, location)}-test-arbappreg-${serviceShort}'
//   params: {}
// }

module hciClusterPreqs '../../../../../../utilities/e2e-template-assets/templates/azure-stack-hci/modules/azureStackHCIClusterPreqs/ashciPrereqs.bicep' = {
  dependsOn: [
    hciHostDeployment
  ]
  name: '${uniqueString(deployment().name, location)}-test-hciclusterreqs-${serviceShort}'
  params: {
    location: location
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    arcNodeResourceIds: arcNodeResourceIds
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    keyVaultDiagnosticStorageAccountName: keyVaultDiagnosticStorageAccountName
    deploymentUsername: deploymentUsername
    deploymentUserPassword: localAdminAndDeploymentUserPass
    hciResourceProviderObjectId: hciResourceProviderObjectId //?? microsoftGraphResources.outputs.hciRPServicePrincipalId
    keyVaultName: keyVaultName
    localAdminPassword: localAdminAndDeploymentUserPass
    localAdminUsername: localAdminUsername
    tenantId: tenantId
    vnetSubnetId: hciHostDeployment.outputs.vnetSubnetId
  }
}

module hciCluster_validate '../../../../cluster/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-test-nichciclustervalidate-${serviceShort}'
  params: {
    clusterNodeNames: clusterNodeNames
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    customLocationName: customLocationName
    defaultGateway: defaultGateway
    deploymentMode: 'Validate'
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    endingIPAddress: endingIPAddress
    keyVaultName: keyVaultName
    name: name
    networkIntents: networkIntents
    startingIPAddress: startingIPAddress
    storageConnectivitySwitchless: false
    storageNetworks: storageNetworks
    subnetMask: subnetMask
  }
  dependsOn: [
    hciClusterPreqs
  ]
}

module hciCluster_deploy '../../../../cluster/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-test-nichciclusterdeploy-${serviceShort}'
  params: {
    clusterNodeNames: clusterNodeNames
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    customLocationName: customLocationName
    defaultGateway: defaultGateway
    deploymentMode: 'Deploy'
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    endingIPAddress: endingIPAddress
    keyVaultName: keyVaultName
    name: name
    networkIntents: networkIntents
    startingIPAddress: startingIPAddress
    storageConnectivitySwitchless: false
    storageNetworks: storageNetworks
    subnetMask: subnetMask
  }
  dependsOn: [
    hciCluster_validate
  ]
}

resource logicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2023-09-01-preview' = {
  name: 'lnet-test01'
  location: location
  extendedLocation: {
    type: 'CustomLocation'
    name: resourceId('Microsoft.ExtendedLocation/customLocations', customLocationName)
  }
  properties: {
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.20.0.128/25'
          ipAllocationMethod: 'Static'
          ipPools: [
            {
              start: '10.20.0.130'
              end: '10.20.0.135'
            }
          ]
          routeTable: {
            properties: {
              routes: [
                {
                  name: 'default'
                  properties: {
                    addressPrefix: '0.0.0.0/0'
                    nextHopIpAddress: '10.20.0.129'
                  }
                }
              ]
            }
          }
        }
      }
    ]
    dhcpOptions: {
      dnsServers: dnsServers
    }
    vmSwitchName: 'ComputeSwitch(compute)'
  }
  dependsOn: [
    hciCluster_deploy
  ]
}

output customLocationId string = resourceId('Microsoft.ExtendedLocation/customLocations', customLocationName)
output subnetId string = logicalNetwork.id

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
