var domainName = 'quberatron.com'
var vmName = 'qbxad1dev'
var scriptStorageName = 'qbxstscriptsdev'
var scriptStoragePath = 'scripts/CreateForest.ps1'

resource scriptStorage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: scriptStorageName
}

//Deploy the ADDS build script and convert the VM into a fully operational AD server
module DeployADDS 'modules/deployADDS.bicep' = {
  name: 'DeployADDS'
  params: {
    location: 'uksouth'
    tags: {}
    domainName: domainName
    vmName: vmName
    storageURI: '${scriptStorage.properties.primaryEndpoints.blob}${scriptStoragePath}'
  }
}
