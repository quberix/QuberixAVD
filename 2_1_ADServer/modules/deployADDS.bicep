//This module is solely for the use of deploying the custom extension for building the VM as an AD server

@description('Location of the Resources. Default: UK South')
param location string

@description('Tags to be applied to all resources')
param tags object

@description('Name of the AD VM to build into an ADDS')
param vmName string

@description('Name of the domain to create')
param domainName string

@description('Full URI path to the script to run on the AD server')
param storageURI string

//Get the existing virtual machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-08-01' existing = {
  name: vmName
}


resource BuildADDS 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'BuildADDS'
  parent: virtualMachine
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: false
    enableAutomaticUpgrade: false
    protectedSettings: {
      fileUris: [
        storageURI
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File CreateForest.ps1 -DomainName ${domainName}'
    }
  }
}
