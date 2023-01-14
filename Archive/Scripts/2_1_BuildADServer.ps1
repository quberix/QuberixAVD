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

#Switch to the appropriate environment
Write-Host "Switching to the required subscription" -ForegroundColor Green
az account set --subscription $localConfig.subscriptionName

#Deploy the resources either live or as a Dry Run
if ($dryrun -ne $true) {
    Write-Host "Running the AD Server Build - Deploying Resources" -ForegroundColor Yellow
    az deployment sub create --location $localConfig.location --template-file "../Server_AD/azuredeploy.bicep" --parameters localenv=$localenv --verbose
} else {
    Write-Host "Running the AD Server Build - Dry-Run mode" -ForegroundColor Green
    az deployment sub create --location $localConfig.location --template-file "../Server_AD/azuredeploy.bicep" --parameters localenv=$localenv --verbose --what-if
}


Write-Host "Finished"