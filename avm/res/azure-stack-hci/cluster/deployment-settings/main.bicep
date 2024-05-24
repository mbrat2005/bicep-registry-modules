param deploymentMode string
param clusterName string
param securityConfiguration object
param streamingDataClient bool
param isEuropeanUnionLocation bool
param episodicDataUpload bool
param clusterWitnessStorageAccountName string
param storageConfigurationMode string
param deploymentPrefix string
param domainFqdn string
param subnetMask string
param defaultGateway string
param clusterNodeNames array
param startingIPAddress string
param endingIPAddress string
param dnsServers array
param storageNetworks array
param storageConnectivitySwitchless bool
param enableStorageAutoIp bool
param domainOUPath string
param keyVaultName string
param customLocationName string
param networkIntents array

var arcNodeResourceIds = [
  for (nodeName, index) in clusterNodeNames: resourceId('Microsoft.HybridCompute/machines', nodeName)
]

var storageNetworkList = [
  for (storageAdapter, index) in storageNetworks: {
    name: 'StorageNetwork${index + 1}'
    networkAdapterName: storageAdapter.adapterName
    vlanId: storageAdapter.vlan
    storageAdapterIPInfo: storageAdapter.?storageAdapterIPInfo
  }
]

resource cluster 'Microsoft.AzureStackHCI/clusters@2024-02-15-preview' existing = {
  name: clusterName
}

resource deploymentSettings 'Microsoft.AzureStackHCI/clusters/deploymentSettings@2024-02-15-preview' = if (deploymentMode != 'LocksOnly') {
  name: 'default'
  parent: cluster
  properties: {
    arcNodeResourceIds: arcNodeResourceIds
    deploymentMode: deploymentMode
    deploymentConfiguration: {
      version: '10.0.0.0'
      scaleUnits: [
        {
          deploymentData: {
            securitySettings: {
              hvciProtection: true
              drtmProtection: true
              driftControlEnforced: securityConfiguration.driftControlEnforced
              credentialGuardEnforced: securityConfiguration.credentialGuardEnforced
              smbSigningEnforced: securityConfiguration.smbSigningEnforced
              smbClusterEncryption: securityConfiguration.smbClusterEncryption
              sideChannelMitigationEnforced: true
              bitlockerBootVolume: securityConfiguration.bitlockerBootVolume
              bitlockerDataVolumes: securityConfiguration.bitlockerDataVolumes
              wdacEnforced: securityConfiguration.wdacEnforced
            }
            observability: {
              streamingDataClient: streamingDataClient
              euLocation: isEuropeanUnionLocation
              episodicDataUpload: episodicDataUpload
            }
            cluster: {
              name: clusterName
              witnessType: 'Cloud'
              witnessPath: ''
              cloudAccountName: clusterWitnessStorageAccountName
              azureServiceEndpoint: environment().suffixes.storage
            }
            storage: {
              configurationMode: storageConfigurationMode
            }
            namingPrefix: deploymentPrefix
            domainFqdn: domainFqdn
            infrastructureNetwork: [
              {
                subnetMask: subnetMask
                gateway: defaultGateway
                ipPools: [
                  {
                    startingAddress: startingIPAddress
                    endingAddress: endingIPAddress
                  }
                ]
                dnsServers: dnsServers
              }
            ]
            physicalNodes: [
              for hciNode in arcNodeResourceIds: {
                name: reference(hciNode, '2022-12-27', 'Full').properties.displayName
                // Getting the IP from the first management NIC of the node based on the first NIC name in the managementIntentAdapterNames array parameter
                //
                // During deployment, a management vNIC will be created with the name 'vManagement(managment)' and the IP config will be moved to the new vNIC--
                // this causes a null-index error when re-running the template mid-deployment, after net intents have applied. To workaround, change the name of
                // the management NIC in parameter file to 'vManagement(managment)'
                ipv4Address: (filter(
                  reference('${hciNode}/providers/microsoft.azurestackhci/edgeDevices/default', '2024-01-01', 'Full').properties.deviceConfiguration.nicDetails,
                  nic => nic.?defaultGateway != null
                ))[0].ip4Address
              }
            ]
            hostNetwork: {
              intents: networkIntents
              storageConnectivitySwitchless: storageConnectivitySwitchless
              storageNetworks: storageNetworkList
              enableStorageAutoIp: enableStorageAutoIp
            }
            adouPath: domainOUPath
            secretsLocation: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}'
            optionalServices: {
              customLocation: customLocationName
            }
          }
        }
      ]
    }
  }
}
