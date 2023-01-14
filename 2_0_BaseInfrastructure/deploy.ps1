# this script will deploy the base infrastructure for the lab

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [Bool]$deployBastion = $true
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
    Write-Host "DRYRUN: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Yellow
} else {
    Write-Host "LIVE: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Green
}

New-AzSubscriptionDeployment -Name "BaseInfrastructure" -Location $localConfig.$localenv.location -Verbose -TemplateFile "../2_0_BaseInfrastructure/deploy.bicep" -WhatIf:$dryrun -TemplateParameterObject @{
    localenv=$localenv
    location=$localConfig.$localenv.location
    tags=$localConfig.$localenv.tags
    boundaryVnetCIDR=$localConfig.$localenv.boundaryVnetCIDR
    boundaryVnetBastionCIDR=$localConfig.$localenv.boundaryVnetBastionCIDR
    deployBastion=$deployBastion
}


Write-Host "Finished" -foregroundColor Green
