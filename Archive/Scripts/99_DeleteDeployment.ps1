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
    Write-Host "Error: Please specify a valid environment to delete the deployed resorces from [dev | prod]" -ForegroundColor Red
    exit 1
}

#Get the config for the selected local environment
$localConfig = Get_Environment_Config $localenv

$deployedRGs = @(
    $localConfig.coreRG
    $localConfig.adRG
)

#Login to azure
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    az login
}

#Get user confirmation
Write-Host "Delete Deployed Resources:"
Write-Host " - Subscription: $($localConfig.subscriptionName)"
foreach ($RG in $deployedRGs) {
    Write-Host " - Resource Group: $RG"
}
if ($dryrun) {
    Write-Host " - DryRun: YES (will not delete resources)" -ForegroundColor Green
} else {
    Write-Host " - DryRun: NO (will delete resources)" -ForegroundColor Red
    Write-Host ""
    Write-Host "WARNING: Resources cannot be recovered once deleted.  ALL resources in the resource group will be deleted." -ForegroundColor Red
    Write-Host ""
}

$confirmation = Read-Host "Do you want to Proceed (y/n):"

#Delete the resource groups and associated resources to remove everything that was deployed
if ($confirmation -eq 'y') {
    #Change context to the correct subscription
    $subname = $localConfig.subscriptionName
    $subid = $localConfig.subscriptionID
    Write-Host "Changing subscription to: $subname" -ForegroundColor Green
    az account set --subscription $subid
    if ((az account show --query id -o tsv) -ne $subid) {
        Write-Host "ERROR: Cannot change to subscription: $subname ($subid)" -ForegroundColor Red
        exit 1
    }

    Write-Host ""

    foreach ($RG in $deployedRGs) {
        if ($dryrun -ne $true) {
            Write-Host "Deleting Resource Group - $RG" -ForegroundColor Yellow
            az group delete --resource-group $RG --force-deletion-types Microsoft.Compute/virtualMachines #--yes
        } else {
            Write-Host "Deleting Resource Group $RG - Dry-Run mode" -ForegroundColor Green
            Write-Host "The following resources would be deleted:"
            az resource list --resource-group $RG --output table
        }
        Write-Host ""
    }
}

Write-Host "Finished"
Write-Host ""