<#
    .SYNOPSIS
        Add <n> hosts to an existing host pool

    .DESCRIPTION
        this script will add <n> hosts to the existing traditional host pool.  The script is currently reliant on the details
        stored in the deployconfig configuration module, but could easily be updated to accept a host pool name and RG.

        It determines the number of already existing hosts, then runs the STD AVD host deployment BICEP template to add the virtual
        machines, ensure that they are domain joined then adds them to the host pool.

        NOTE: Make sure that the AD server you are using (shown in the deployconfig) is switched on and operational otherwise this will fail
#>
param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Parameter(Mandatory)]
    [int]$addHosts = 0,
    [Bool]$dryrun = $true,
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

#Check if we are doing a DRYRUN (no change) of the deployment.
if ($dryrun) {
    Write-Host "DRYRUN: This will not deploy resources or make any changes" -ForegroundColor Yellow
} else {
    Write-Host "LIVE: This will deploy resources and make changes to infrastructure" -ForegroundColor Green
}

#Get the list of existing hosts in the host pool
$hpRG = $localConfig.$localenv.desktops.avdstd.hostPoolRG
$hpName = $localConfig.$localenv.desktops.avdstd.hostPoolName


#Get the host pool data
$er = ""
$hosts = Get-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -ErrorVariable er
if ($er) {
    Write-Log "Unable to get Host Pool Hosts data for $hpRG / $hpName - permissions?" -logType fatal
    Write-Log "ERROR: $er" 
    exit 1
}

#Get the number of hosts in the pool
$existHostCount = $hosts.count
$newHostCount = $existHostCount + $addHosts
if ($newHostCount -le $existHostCount) {
    Write-Host "ERROR: The number of hosts to add must be greater than zero" -ForegroundColor Red
    exit 1
}

Write-Host "Adding $addHosts hosts to the host pool for a total of $newHostCount" -ForegroundColor Green

#Generate a new HostPool Token
Write-Host "Generate a new host pool token" -ForegroundColor Green
$expiryTime = $((Get-Date).ToUniversalTime().AddHours(8).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))

if (-not $dryrun) {
    $hpToken = (New-AzWvdRegistrationInfo -HostPoolName $hpName -ResourceGroupName $hpRG -ExpirationTime $expiryTime).token
} else {
    $hpToken = "dryrun"
}

if (-not $hpToken) {
    Write-Host "ERROR: Unable to generate a new host pool token" -ForegroundColor Red
    exit 1
}

#Check if there is a scale plan
$scalePlanState = $false
$scalePlanExists = Get-HostPoolScalingPlanExists -hostPoolName $hpName -hostPoolRG $hpRG
if ($scalePlanExists) {
    $scalePlanState = Get-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG

    #If there is a scale plan, then disable it
    if ($scalePlanState) {
        Write-Host "Disabling the Scaling Plan for hostpool: $hpName" -ForegroundColor Green
        if (-not $dryrun) {
            $result = Set-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG -enabled $false
            if ($result) {
                Write-Host "Scaling plan disabled" -ForegroundColor Green
            } else {
                Write-Host "ERROR: Failed to disable the scaling plan" -ForegroundColor Red
                exit 1
            }
        }
    }
}

#Run the VM Hosts bicep deployment
Write-Host "Deploying the Virtual Machines and joining them to the hostpool" -ForegroundColor Green
$out2 = New-AzSubscriptionDeployment -Name "AddHostsToStandardAVDHostPool" -Location $localConfig.$localenv.location -Verbose -TemplateFile "..\2_hosts.bicep" -WhatIf:$dryrun -TemplateParameterObject @{
    localenv=$localenv
    location=$localConfig.$localenv.location
    tags=$localConfig.$localenv.tags
    productShortName = $localConfig.general.productShortName
    adDomainName = $localConfig.general.ADDomain
    adOUPath = $localConfig.$localenv.desktops.avdstd.ou
    hostpoolName = $hpName
    hostPoolRG = $hpRG
    avdVnetName = $localConfig.$localenv.desktops.avdstd.vnetName
    avdSubnetName = $localConfig.$localenv.desktops.avdstd.snetName
    galleryImageName = $localConfig.$localenv.desktops.avdstd.image
    hostPoolHostNamePrefix = $localConfig.$localenv.desktops.avdstd.prefix
    hostPoolToken = $hpToken
    hostPoolHostsCurrentInstances = $existHostCount
    hostPoolHostsToCreate = $addHosts
}

#check to make sure it has run successfully
if (-Not $out2) {
    Write-Host "ERROR: Failed to deploy the virtual machines" -ForegroundColor Red
} else {
    Write-Host "Virtual Machines deployed successfully" -ForegroundColor Green
}

#Reinstate the Scale plan on the hostpool if it was previously enabled
if ($scalePlanExists) {
    Write-Host "Restoring the state of the scaling plan: $hpName to $scalePlanState" -ForegroundColor Green
    if (-not $dryrun) {
        $result = Set-HostPoolScalingPlanState -hostPoolName $hpName -hostPoolRG $hpRG -enabled $scalePlanState
        if ($result) {
            Write-Host "Scaling plan updated successfully - scaling now set to: $scalePlanState" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Failed to set the scaling plan state" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "Deployment Complete" -ForegroundColor Green
