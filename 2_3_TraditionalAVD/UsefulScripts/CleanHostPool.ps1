<#
    .SYNOPSIS
        This script will remove any hostpool hosts that have been orphaned (i.e. have no attached VM)
    
    .DESCRIPTION
        The grabs a list of the hostpools hosts and then checks to see if there is a VM attached to each host.
        If there is no underlying VM attached to the host, then the host is removed from the hostpool.
#>

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [String]$desktopName = 'avdstd',
    [Bool]$dologin = $true
)

Write-Host "Running this script will remove any hostpool hosts that have been orphaned (i.e. have no attached VM)" -ForegroundColor Green

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
$hostPoolRG = $localConfig.$localenv.desktops.$desktopName.hostPoolRG
$hostPoolName = $localConfig.$localenv.desktops.$desktopName.hostPoolName

#Get a list of hosts in the host pool
$er = ""
$hosts = Get-AzWvdSessionHost -ResourceGroupName $hostPoolRG -HostPoolName $hostPoolName -ErrorVariable er
if ($er) {
    Write-Log "Unable to get Host Pool Hosts data for $hostPoolRG / $hostPoolName - permissions?" -logType fatal
    Write-Log "ERROR: $er" 
    exit 1
}

#Get the VM name from each host then check if the VM exists
$orphenedHosts = @()
foreach ($hostData in $hosts) {
    $vmName = ((($hostData.Name).split('/'))[-1]).Trim()     #Get the last element in the array
    Write-Host "Checking hostpool host $($hostData.Name) for valid VM: $vmName"
    $er = ""
    $vm = Get-AzVM -ResourceGroupName $hostPoolRG -Name $vmName -ErrorVariable er
    if ($er) {
        Write-Host "Hostpool Host $($hostData.Name) has no VM attached" -ForegroundColor Yellow
        $orphenedHosts += $hostData
    } else {
        Write-Host "Hostpool Host $($hostData.Name) is valid" -ForegroundColor Green
    }
}

#List the orphened hosts
if ($orphenedHosts.count -gt 0) {
    Write-Host "The following hosts are orphened and will be removed:" -ForegroundColor Yellow
    foreach ($host in $orphenedHosts) {
        Write-Host " - Host: $($host.Name)" -ForegroundColor Grey
    }

    #Ask the user if they want to remove the orphened hosts
    $answer = Read-Host "Do you want to remove the orphened hosts? [y/n]"
    if ($answer -eq 'y') {
        #Remove the orphened hosts
        foreach ($host in $orphenedHosts) {
            Write-Host "Removing host: $($host.Name)" -ForegroundColor Green
            $er = ""
            Remove-AzWvdSessionHost -ResourceGroupName $hostPoolRG -HostPoolName $hostPoolName -Name $host.Name -ErrorVariable er
            if ($er) {
                Write-Host "ERROR: Unable to remove host: $($host.Name)" -ForegroundColor Red
            } else {
                Write-Host "Removed host: $($host.Name)" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "No hosts removed" -ForegroundColor Green
    }
} else {
    Write-Host "No orphened hosts found" -ForegroundColor Green
}

Write-Host "Finished" -ForegroundColor Green