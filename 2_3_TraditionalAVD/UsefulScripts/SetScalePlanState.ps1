<#
    .SYNOPSIS
    Sets the state of the scaling plan for a hostpool

    .DESCRIPTION
    Changes the state of the Azure Scaling Plan that is associated with the hostpool
    Effectivly enables or disables it.

#>

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [String]$desktopName = 'avdstd',
    [Parameter(Mandatory)]
    [Bool]$enabled,
    [Bool]$dologin = $true
)

#Import the central powershell configuration module
Import-Module ../../PSConfig/deployConfig.psm1 -Force

#Import the Host Library
Import-Module "$PSScriptRoot/hostLibrary.psm1" -Force

#Get the local environment into a consistent state
$localenv = $localenv.ToLower()

if ((!$localenv) -and ($localenv -ne 'dev') -and ($localenv -ne 'prod')) {
    Write-Host "Error: Please specify a valid environment to deploy to [dev | prod]" -ForegroundColor Red
    exit 1
}

write-host "Working with environment: $localenv"

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

#Get the hostpool RG and name from the config
$hpRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
$hpName = $localConfig.$localenv.desktops.$desktopName.hostPoolName

#Check if there is a scale plan
$scalePlanExists = Get-HostPoolScalingPlanExists -hostPoolName $hpName -hostPoolRG $hpRG
if ($scalePlanExists) {
    $scalePlanState = Get-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG

    if ($scalePlanState -eq $enabled) {
        Write-Host "Scaling plan is already in the desired state" -ForegroundColor Green
        exit 0
    }

    Write-Host "Setting Scaling Plan for hostpool: $hpName to $state" -ForegroundColor Green
    $result = Set-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG -enabled $enabled
    if ($result) {
        Write-Host "Scaling plan state change successful" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to change the state of the scaling plan" -ForegroundColor Red
        exit 1
    }

} else {
    Write-Host "No scale plan found for hostpool: $hpName" -ForegroundColor Yellow
    exit 1
}

Write-Host "Deployment Complete" -ForegroundColor Green
