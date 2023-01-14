# this script will deploy the stand alone VM based AD server and create a domain

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [Bool]$deployADServer = $true
)

#Import the central powershell configuration module
Import-Module ../PSConfig/deployConfig.psm1 -Force

#Get the local environment into a consistent state
$localenv = $localenv.ToLower()

if ((!$localenv) -and ($localenv -ne 'dev') -and ($localenv -ne 'prod')) {
    Write-Host "Error: Please specify a valid environment to deploy to [dev | prod]" -ForegroundColor Red
    exit 1
}

#Get the config for the selected local environment
$localConfig = Get-Config

#Login to azure
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $localConfig.$localenv.subscriptionID
}

#Get the subsccription ID
$subid = (Get-AzContext).Subscription.Id

#check that the subscription ID matchs that in the config
if ($subid -ne $localConfig.$localenv.subscriptionID) {
    #they dont match so try and change the context
    Write-Host "Changing context to subscription: $subname ($subid)" -ForegroundColor Yellow
    $context = Set-AzContext -SubscriptionId $localConfig.$localenv.subscriptionID

    if ($context.Subscription.Id -ne $localConfig.$localenv.subscriptionID) {
        Write-Host "ERROR: Cannot change to subscription: $subname ($subid)" -ForegroundColor Red
        exit 1
    }

    Write-Host "Changed context to subscription: $subname ($subid)" -ForegroundColor Green
}

#Deploy the bicep using a subscription based deployment
if ($dryrun) {
    Write-Host "DRYRUN: Running the AD VM Deployment- Deploying Resources" -ForegroundColor Yellow
} else {
    Write-Host "LIVE: Running the AD VM Deployment - Deploying Resources" -ForegroundColor Green
}

#Get the IP address of the location where I am running my script to add this to the storage account firewall
Write-Host "Getting the IP address of the location where the script is running" -ForegroundColor Green
$scriptIPAddress = (Invoke-WebRequest ifconfig.me/ip).Content.Trim()

#Get the ADDS admin password to configure
$pass = Read-Host 'Please enter a Domain Admin password to use' -AsSecureString

#Deploy the base line Azure infrastructure required for the AD VM
Write-Host "Deploying the AD Infrastructure" -ForegroundColor Green
$out = New-AzSubscriptionDeployment `
    -Name "ADDeployment" `
    -Location $localConfig.$localenv.location `
    -Verbose `
    -TemplateFile "../2_1_ADServer/1_deployInfra.bicep" `
    -WhatIf:$dryrun `
    -domainSafeModePass $pass `
    -VMADAdminPassword $pass `
    -TemplateParameterObject @{
        localenv=$localenv
        location=$localConfig.$localenv.location
        tags=$localConfig.$localenv.tags
        IDVnetCIDR=$localConfig.$localenv.idVnetCIDR
        IDSnetADCIDR=$localConfig.$localenv.idSnetADCIDR
        VMADAdminUserName=$localConfig.general.ADUSerName
        scriptContainerName=($localConfig.general.ADForestScript).split('/')[0]
        localScriptIPAddress=$scriptIPAddress
    }

#Grab the outputs from the BICEP deployment
$ADSnetId = $out.Outputs.identityADSnetId.value
$ADScriptAccountName = $out.Outputs.storageAccountName.value
$ADScriptAccountRG = $out.Outputs.storageAccountRG.value

if (-not $ADScriptAccountName) {
    Write-Host "ERROR: Could not get the storage account name from the deployment - check for deployment errors" -ForegroundColor Red
    exit 1
}

if (-not $ADSnetId) {
    Write-Host "ERROR: Could not get the AD Subnet Resource ID from the deployment - check for deployment errors" -ForegroundColor Red
    exit 1
}

#Upload the ADDS build script to the storage account
Write-Host "Getting the Script storage account ($ADScriptAccountName) and uploading the 'Createforest.ps1' script" -ForegroundColor Green

#Get the storage account context
$stContext = Get-AzStorageAccount -ResourceGroupName $ADScriptAccountRG -Name $ADScriptAccountName

#Copy the ADDS build script to the storage account
$scriptUpl = @{
    File             = './artifacts/CreateForest.ps1'
    Container        = 'scripts'
    Blob             = "CreateForest.ps1"
    Context          = $stContext.Context
    StandardBlobTier = 'Hot'
  }
  Set-AzStorageBlobContent @scriptUpl -Force:$true


if ($deployADServer) {
    #Deploy the AD VM bicep template
    Write-Host "Deploying the AD VM and configuring it as an ADDS server with domain: $($localConfig.general.ADDomain)" -ForegroundColor Green
    $out = New-AzSubscriptionDeployment `
        -Name "ADDeployment" `
        -Location $localConfig.$localenv.location `
        -Verbose `
        -TemplateFile "../2_1_ADServer/2_deployADVM.bicep" `
        -WhatIf:$dryrun `
        -TemplateParameterObject @{
            localenv=$localenv
            location=$localConfig.$localenv.location
            tags=$localConfig.$localenv.tags
            identityADSnetId=$ADSnetId
            DomainName=$localConfig.general.ADDomain
            VMADAdminUserName=$localConfig.general.ADUSerName
            scriptStorageName=$ADScriptAccountName
            scriptStorageRG=$ADScriptAccountRG
            scriptStoragePath=$localConfig.general.ADForestScript
            VMStaticIpAddress=$localConfig.$localenv.ADStaticIpAddress
            shutdownTime=$localConfig.$localenv.VMADAutoShutdownTime
        }

    $out

    #Storage URI and script should be
    #Should be: https://qbxstscriptsdev.blob.core.windows.net/scripts/CreateForest.ps1


    #Restart the azure VM
    Write-Host "Restarting the AD VM" -ForegroundColor Green
    $serverName = $out.Outputs.vmadServerVMName.value
    $serverRG = $out.Outputs.vmadServerVMRG.value
    if (-not $serverName) {
        Write-Host "ERROR: Could not get the AD VM name from the deployment - check for deployment errors" -ForegroundColor Red
        exit 1
    }
    Restart-AzVM -ResourceGroupName $serverRG -Name $serverName
}

#Remove the IP address of the script running machine.
Write-Host "Cleanup - Removing the IP address of the location where the script is running from the storage account firewall" -ForegroundColor Green
Remove-AzStorageAccountNetworkRule -ResourceGroupName $ADScriptAccountRG -Name $ADScriptAccountName -IPAddressOrRange $scriptIPAddress


Write-Host "Finished" -foregroundColor Green
