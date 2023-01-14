@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@description('Tags to be applied to all resources')
param tags object = {}

@description('Name of the virtual machine to shutdown')
param vmName string

@description('The time of the day to shutdown the VM in format HH:MM')
param shutdownTime string

@description('Who to send the notification to (if required)')
param emailAddress string = ''

//Get the VM
resource vm 'Microsoft.Compute/virtualMachines@2022-08-01' existing = {
  name: vmName
}

//Configure AutoShutdown
resource autoShutdownConfig 'Microsoft.DevTestLab/schedules@2018-09-15' = if (shutdownTime != '') {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    notificationSettings: emailAddress != '' ?{
      status: 'Enabled'
      timeInMinutes: 15
      notificationLocale: 'en'
      emailRecipient: emailAddress
    } : {}

    dailyRecurrence: {
       time: shutdownTime
    }
     timeZoneId: 'UTC'
     taskType: 'ComputeVmShutdownTask'
     targetResourceId: vm.id
  }
}
