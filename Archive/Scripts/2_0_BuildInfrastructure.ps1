param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true
)

#Import the general support library containing config and common functions
import-module -Force "$PSScriptRoot\General"

#Get the local environment into a consistent state
$localenv = $localenv.ToLower()

if ((!$localenv) -and ($localenv -ne 'dev') -and ($localenv -ne 'prod')) {
    Write-Host "Error: Please specify a valid environment to deploy to [dev | prod]" -ForegroundColor Red
    exit 1
}

#Get the config for the selected local environment
$localConfig = Get_Environment_Config $localenv

#Login to azure
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    az login
}

#Change context to the correct subscription
$subname = $localConfig.subscriptionName
$subid = $localConfig.subscriptionID
Write-Host "Changing subscription to: $subname" -ForegroundColor Green
az account set --subscription $subid
if ((az account show --query id -o tsv) -ne $subid) {
    Write-Host "ERROR: Cannot change to subscription: $subname ($subid)" -ForegroundColor Red
    exit 1
}


#Deploy the resources either live or as a Dry Run
if ($dryrun) {
    #Create the resource group (DRYRUN)
    Write-Host "DRYRUN: Creating Resource Group: $($localConfig.coreRG)" -ForegroundColor Yellow
    Write-Host "Running command: az group create --location $($localConfig.location) --resource-group $($localConfig.coreRG)  --tags $($localConfig.tags)"

    #Deploy the core infrastructure (DRYRUN)
    Write-Host "DRYRUN: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Yellow
    az deployment group create --resource-group $localConfig.coreRG --template-file "../2_0_Infrastructure/azuredeploy.bicep" --parameters localenv=$localenv --verbose --what-if

} else {
    #Create the resource group
    Write-Host "Creating Resource Group: $($localConfig.coreRG)" -ForegroundColor Green
    if (az group create --location $($localConfig.location) --resource-group $localConfig.coreRG --tags $localConfig.tags) {
        Write-Host "Resource Group Created"
    } else {
        Write-Host "Failed to create resource group" -ForegroundColor Red
        exit 1
    }

    #Deploy the core infrastructure
    Write-Host "Running the Infrastructure Build" -ForegroundColor Green
    az deployment group create --resource-group $localConfig.coreRG --template-file "..\2_0_CORE_Infrastructure\azuredeploy.bicep" --parameters localenv=$localenv --verbose
}


Write-Host "Finished"