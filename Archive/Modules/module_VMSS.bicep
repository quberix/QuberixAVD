//Virtual machine scale set (windows) module

//TODO: WAD logs from config

//Parameters
@description('Location of the Resources.')
param location string

@description('Default Tags to apply')
param tags object

// @description('Diagnostic Log Analytics ID')
// param diagLawID string = ''

@description('Name of the VMSS')
param vmssName string

@description('Optional - Number of Virtual Machines to start by default. Default: 1')
param vmssCapacity int = 1

@description('Optional - Size of the VMs for the VMSS to spin up.  Default: Standard_B2s')
param vmSize string = 'Standard_B2s'

@description('Optional - Configure the upgrade policy of the VMSS.  Default: Automatic')
@allowed([
  'Automatic'
  'Manual'
  'Rolling'
])
param upgradePolicy string = 'Automatic'

@description('Optional - SKU for the VMSS to use')
@allowed([
  'Standard'
  'Basic'
])
param vmssSku string = 'Standard'

@description('References to either an image library image or standard vm image')
param vmssImageObject object
//Configured as either:
// imageReference: {
//   id: sharedImageGalleryPath
//   version: specific version name (optional)
// }
// OR
// imageReference: {
//   offer: offerName
//   publisher: publisherName
//   sku: skuName
// }

@description('Optional - List of data disks.  See [API](https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachinescalesets?tabs=bicep) for detailed information.  Default: []')
param vmDataDisksList array = []

@description('Prefix name for virtual machines.  Max length 12')
@maxLength(12)
param vmNamePrefix string

@description('The vnet object from the Config')
param vmssVnetObject object

@description('The name of the subnet within the vnet object that the VMs will join')
param vmssSnetName string

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

@description('Optional - Domain OU Path to add the VMSS Object')
param vmDomainOUPath string = ''

@description('Provide the diagnostic storage object from config which includes storage account and log analytics')
param diagnosticsObject object

//VARIABLES
var namePrefix = toUpper(vmNamePrefix)
var nicPrefix = toUpper('${vmNamePrefix}-NIC')
var nicIPConfigName = toUpper('${vmNamePrefix}-NIC-IPCONFIG')

//VM Diagnostics - performance and metric (https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/diagnostics-template)
var wadlogs = '<WadCfg> <DiagnosticMonitorConfiguration overallQuotaInMB="4096" xmlns="http://schemas.microsoft.com/ServiceHosting/2010/10/DiagnosticsConfiguration"> <DiagnosticInfrastructureLogs scheduledTransferLogLevelFilter="Error"/> <WindowsEventLog scheduledTransferPeriod="PT1M" > <DataSource name="Application!*[System[(Level = 1 or Level = 2)]]" /> <DataSource name="Security!*[System[(Level = 1 or Level = 2)]]" /> <DataSource name="System!*[System[(Level = 1 or Level = 2)]]" /></WindowsEventLog>'
var wadperfcounters1 = '<PerformanceCounters scheduledTransferPeriod="PT1M"><PerformanceCounterConfiguration counterSpecifier="\\Processor(_Total)\\% Processor Time" sampleRate="PT15S" unit="Percent"><annotation displayName="CPU utilization" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Processor(_Total)\\% Privileged Time" sampleRate="PT15S" unit="Percent"><annotation displayName="CPU privileged time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Processor(_Total)\\% User Time" sampleRate="PT15S" unit="Percent"><annotation displayName="CPU user time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Processor Information(_Total)\\Processor Frequency" sampleRate="PT15S" unit="Count"><annotation displayName="CPU frequency" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\System\\Processes" sampleRate="PT15S" unit="Count"><annotation displayName="Processes" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Process(_Total)\\Thread Count" sampleRate="PT15S" unit="Count"><annotation displayName="Threads" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Process(_Total)\\Handle Count" sampleRate="PT15S" unit="Count"><annotation displayName="Handles" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\% Committed Bytes In Use" sampleRate="PT15S" unit="Percent"><annotation displayName="Memory usage" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\Available Bytes" sampleRate="PT15S" unit="Bytes"><annotation displayName="Memory available" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\Committed Bytes" sampleRate="PT15S" unit="Bytes"><annotation displayName="Memory committed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\Memory\\Commit Limit" sampleRate="PT15S" unit="Bytes"><annotation displayName="Memory commit limit" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\% Disk Time" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk active time" locale="en-us"/></PerformanceCounterConfiguration>'
var wadperfcounters2 = '<PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\% Disk Read Time" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk active read time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\% Disk Write Time" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk active write time" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Transfers/sec" sampleRate="PT15S" unit="CountPerSecond"><annotation displayName="Disk operations" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Reads/sec" sampleRate="PT15S" unit="CountPerSecond"><annotation displayName="Disk read operations" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Writes/sec" sampleRate="PT15S" unit="CountPerSecond"><annotation displayName="Disk write operations" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Bytes/sec" sampleRate="PT15S" unit="BytesPerSecond"><annotation displayName="Disk speed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Read Bytes/sec" sampleRate="PT15S" unit="BytesPerSecond"><annotation displayName="Disk read speed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\PhysicalDisk(_Total)\\Disk Write Bytes/sec" sampleRate="PT15S" unit="BytesPerSecond"><annotation displayName="Disk write speed" locale="en-us"/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier="\\LogicalDisk(_Total)\\% Free Space" sampleRate="PT15S" unit="Percent"><annotation displayName="Disk free space (percentage)" locale="en-us"/></PerformanceCounterConfiguration></PerformanceCounters>'
var wadcfgxstart = '${wadlogs}${wadperfcounters1}${wadperfcounters2}<Metrics resourceId="'
var wadmetricsresourceid = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/virtualMachines/'
var wadcfgxend = '"><MetricAggregation scheduledTransferPeriod="PT1H"/><MetricAggregation scheduledTransferPeriod="PT1M"/></Metrics></DiagnosticMonitorConfiguration></WadCfg>'


//Get the existing subnet
resource subnet 'Microsoft.Network/virtualnetworks/subnets@2015-06-15' existing = {
  name: '${vmssVnetObject.vnetName}/${vmssSnetName}'
  scope: resourceGroup(vmssVnetObject.subscriptionID,vmssVnetObject.RG)
}

//Get the existing Log Analytics
resource DiagLAW 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: diagnosticsObject.name
  scope: resourceGroup(diagnosticsObject.subscription,diagnosticsObject.RG)
}


//Get existing diag storage account
resource DiagStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: diagnosticsObject.storageName
  scope: resourceGroup(diagnosticsObject.subscription,diagnosticsObject.rg)
}

//Get the existing

//Build the scale set
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-04-01' = {
  name: vmssName
  location: location
  tags: tags
  sku: {
    name: vmSize
    tier: vmssSku
    capacity: vmssCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: upgradePolicy
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: vmssImageObject
        dataDisks: vmDataDisksList

      }
      osProfile: {
        computerNamePrefix: namePrefix
        adminUsername: vmAdminName
        adminPassword: vmAdminPassword
        windowsConfiguration: {
          enableAutomaticUpdates: true
          provisionVMAgent: true
        }
      }

      networkProfile: {
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
}

//Join the domain
resource joindomain 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (vmDomainAdminName != '') {
  name: 'JoinDomain'
  parent: vmss
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
resource endpointProtection 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-04-01' = {
  name: 'EndpointProtection'
  parent: vmss
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      'AntimalwareEnabled': true
      'RealtimeProtectionEnabled': true
      'ScheduledScanSettings': {
        'isEnabled': true
        'scanType': 'Full'
        'day': '7'
        'time': '120'
      }
    }
  }
  dependsOn: [
    joindomain
  ]
}

//Guest extensions
resource guestExtensions 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-04-01' = {
  name: 'GuestExtensions'
  parent: vmss
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
resource VMDiagnostics 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-11-01' = {
  name: 'Microsoft.Insights.VMDiagnosticsSettings'
  parent: vmss
  properties: {
    publisher: 'Microsoft.Azure.Diagnostics'
    type: 'IaaSDiagnostics'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: true
    settings: {
      storageAccount: DiagStorageAccount.id
      xmlCfg: base64('${wadcfgxstart}${wadmetricsresourceid}${vmNamePrefix}${wadcfgxend}')
    }
    protectedSettings: {
      storageAccountName: DiagStorageAccount.name
      storageAccountKey: DiagStorageAccount.listkeys().keys[0].value
      storageAccountEndPoint: environment().suffixes.storage
    }
  }

  dependsOn: [
    guestExtensions
  ]
}

//Monitoring Agent
resource omsExtension 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-11-01' = {
  name: 'omsExtension'
  parent: vmss
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
    VMDiagnostics
  ]
}
