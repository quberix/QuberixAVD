//Virtual machine (windows) module

//TODO: WAD logs from config

//ADD identies
//Add av zones

//Parameters
@description('Location of the Resources.')
param location string

@description('Default Tags to apply')
param tags object

// @description('Diagnostic Log Analytics ID')
// param diagLawID string = ''

@description('Name of the VM')
param vmName string

@description('Optional - Size of the VMs for the VM to spin up.  Default: Standard_B2s')
param vmSize string = 'Standard_B2s'

@description('References to either an image library image or standard vm image')
param vmImageObject object
//Configured as either:
// {
//   id: sharedImageGalleryPath
//   version: specific version name (optional)
// }
// OR
// {
//   offer: offerName
//   publisher: publisherName
//   sku: skuName
// }

@description('Optional - List of data disks.  See [API](https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachinescalesets?tabs=bicep) for detailed information.  Default: []')
param vmDataDisksList array = []

@description('Name for the actual running virtual machines.  Max length 15')
@maxLength(15)
param vmComputerName string

@description('The vnet object from the Config')
param vnetConfig object

@description('The name of the subnet within the vnet object that the VMs will join')
param snetName string

@description('Local VM Admin Username')
@secure()
param vmAdminName string

@description('Local VM Admin Password')
@secure()
param vmAdminPassword string

@description('Optional - Domain Admin Username')
@secure()
param vmDomainAdminName string = ''

@description('Optional - Domain Admin Password')
@secure()
param vmDomainAdminPassword string = ''

@description('Optional - The Domain Name')
param vmDomainName string = 'udal.nhs.uk'

@description('Optional - Domain OU Path to add the VM Object')
param vmDomainOUPath string = ''

//Hot patching info: https://docs.microsoft.com/en-us/azure/automanage/automanage-windows-server-services-overview#getting-started-with-windows-server-azure-edition
@description('Optional - Enable Hot patching on the virtual machine - default: false')
param enableHotPatching bool = false

//while we have a module to get the ID of the LAW, for things like the OMS extension, it needs access to the keys as well, so we need to reference it as a resource
@description('The config object containing the references to an existing Log Analytics and diagnostic storage account to send debug info to.')
param diagObject object

//VARIABLES
var computerName = toUpper(vmComputerName)
var nicPrefix = toUpper('${vmName}-NIC')
var nicIPConfigName = toUpper('${vmName}-NIC-IPCONFIG')

//VM Diagnostics - performance and metric (https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/diagnostics-template)
// var wadlogs = '<WadCfg> <DiagnosticMonitorConfiguration overallQuotaInMB="4096" xmlns="http://schemas.microsoft.com/ServiceHosting/2010/10/DiagnosticsConfiguration"> <DiagnosticInfrastructureLogs scheduledTransferLogLevelFilter="Error"/> <WindowsEventLog scheduledTransferPeriod="PT1M" > <DataSource name="Application!*[System[(Level = 1 or Level = 2)]]" /> <DataSource name="Security!*[System[(Level = 1 or Level = 2)]]" /> <DataSource name="System!*[System[(Level = 1 or Level = 2)]]" /></WindowsEventLog>'
// var wadperfcounters1 = '<PerformanceCounters scheduledTransferPeriod="PT1M"><PerformanceCounterConfiguration counterSpecifier="\\Processor(_Total)\\% Processor Time" sampleRate="PT15S" unit="Percent"><annotation displayName="CPU utilization" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Processor(_Total)\\% Privileged Time" sampleRate="PT15S" unit="Percent"><annotation displayName="CPU privileged time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Processor(_Total)\\% User Time" sampleRate="PT15S" unit="Percent"><annotation displayName="CPU user time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Processor Information(_Total)\\Processor Frequency" sampleRate="PT15S" unit="Count"><annotation displayName="CPU frequency" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\System\\Processes" sampleRate="PT15S" unit="Count"><annotation displayName="Processes" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Process(_Total)\\Thread Count" sampleRate="PT15S" unit="Count"><annotation displayName="Threads" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Process(_Total)\\Handle Count" sampleRate="PT15S" unit="Count"><annotation displayName="Handles" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\% Committed Bytes In Use" sampleRate="PT15S" unit="Percent"><annotation displayName="Memory usage" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\Available Bytes" sampleRate="PT15S" unit="Bytes"><annotation displayName="Memory available" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\Committed Bytes" sampleRate="PT15S" unit="Bytes"><annotation displayName="Memory committed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\Commit Limit" sampleRate="PT15S" unit="Bytes"><annotation displayName="Memory commit limit" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\% Disk Time" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk active time" locale="en-us"/></PerformanceCounterConfiguration>'
// var wadperfcounters2 = '<PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\% Disk Read Time" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk active read time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\% Disk Write Time" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk active write time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Transfers/sec" sampleRate="PT15S" unit="CountPerSecond"><annotation displayName="Disk operations" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Reads/sec" sampleRate="PT15S" unit="CountPerSecond"><annotation displayName="Disk read operations" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Writes/sec" sampleRate="PT15S" unit="CountPerSecond"><annotation displayName="Disk write operations" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Bytes/sec" sampleRate="PT15S" unit="BytesPerSecond"><annotation displayName="Disk speed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Read Bytes/sec" sampleRate="PT15S" unit="BytesPerSecond"><annotation displayName="Disk read speed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Write Bytes/sec" sampleRate="PT15S" unit="BytesPerSecond"><annotation displayName="Disk write speed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\LogicalDisk(_Total)\\% Free Space" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk free space (percentage)" locale="en-us"/></PerformanceCounterConfiguration></PerformanceCounters>'
// var wadcfgxstart = '${wadlogs}${wadperfcounters1}${wadperfcounters2}<Metrics resourceId="'
// var wadmetricsresourceid = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/virtualMachines/'
// var wadcfgxend = '"><MetricAggregation scheduledTransferPeriod="PT1H"/><MetricAggregation scheduledTransferPeriod="PT1M"/></Metrics></DiagnosticMonitorConfiguration></WadCfg>'


//Get the existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: '${vnetConfig.vnetName}/${snetName}'
  scope: resourceGroup(vnetConfig.subscriptionID,vnetConfig.rg)
}

//Get the existing Log Analytics
resource DiagLAW 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: diagObject.name
  scope: resourceGroup(diagObject.subscription,diagObject.rg)
}


//Get existing diag storage account
// resource DiagStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
//   name: diagObject.storageName
//   scope: resourceGroup(diagObject.subscription,diagObject.rg)
// }

//Build the VM
resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }

    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: vmImageObject
      dataDisks: vmDataDisksList
    }

    osProfile: {
      computerName: computerName
      adminUsername: vmAdminName
      adminPassword: vmAdminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        timeZone: 'GMT Standard Time'
        patchSettings: {
          assessmentMode: 'ImageDefault'
          enableHotpatching: enableHotPatching
          patchMode: 'AutomaticByOS'
        }
      }
    }

    networkProfile: {
      networkApiVersion: '2020-11-01'
      networkInterfaceConfigurations: [
        {
          name: nicPrefix
          properties: {
            primary: true
            ipConfigurations: [
              {
                name: nicIPConfigName
                properties: {
                  subnet: {
                    id: subnet.id
                  }
                }
              }
            ]
          }
        }
      ]
    }

    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

//Join the domain
resource joindomain 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (vmDomainAdminName != '') {
  name: 'JoinDomain'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: vmDomainName
      ouPath: vmDomainOUPath
      user: vmDomainAdminName
      restart: 'true'
      options: '3'
    }
    protectedSettings: {
      password: vmDomainAdminPassword
    }
  }
}

//Endpoint protection
resource endpointProtection 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: 'EndpointProtection'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: true
      ScheduledScanSettings: {
        isEnabled: true
        scanType: 'Full'
        day: '7'
        time: '120'
      }
    }
  }
  dependsOn: [
    joindomain
  ]
}

//Guest extensions
resource guestExtensions 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: 'GuestExtensions'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: 'ConfigurationforWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [
    endpointProtection
  ]
}

//VM Diagnostics
// resource VMDiagnostics 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
//   name: 'Microsoft.Insights.VMDiagnosticsSettings'
//   parent: vm
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.Diagnostics'
//     type: 'IaaSDiagnostics'
//     typeHandlerVersion: '1.5'
//     autoUpgradeMinorVersion: true
//     settings: {
//       storageAccount: DiagStorageAccount.id
//       xmlCfg: base64('${wadcfgxstart}${wadmetricsresourceid}${computerName}${wadcfgxend}')
//     }
//     protectedSettings: {
//       storageAccountName: DiagStorageAccount.name
//       storageAccountKey: DiagStorageAccount.listkeys().keys[0].value
//       storageAccountEndPoint: environment().suffixes.storage
//     }
//   }

//   dependsOn: [
//     guestExtensions
//   ]
// }

//Monitoring Agent
resource omsExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: 'omsExtension'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceID: DiagLAW.properties.customerId
    }
    protectedSettings: {
      workspaceKey: DiagLAW.listkeys().primarySharedKey
    }
  }
  dependsOn: [
    guestExtensions
  ]
}
