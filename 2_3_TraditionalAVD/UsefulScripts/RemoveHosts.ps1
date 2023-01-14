#A script that will get the number of hosts in the pool, determine their powerstate, connected users and age.
#It will then start by removing the oldest powered off hosts, then the oldest hosts with no users, then the oldest hosts with users (with a user warning)

<#
    .SYNOPSIS
    This script will remove hosts from a host pool

    .DESCRIPTION
    The script will remove a set number of hosts from the host pool as defined by $removeHostCount.  By default it will remove hosts that are
    powered off first, then hosts with no users, then hosts with users (with a user warning).  It will always try and remove the oldest hosts first.

    The script captures enough detail to provide a number of other possible future options i.e. create a parameter that determine the 
    type of host to remove (oldest, most users, least users, etc) then compile the list of hosts to remove.
    For example:
        oldest - places the oldest hosts at the top of the pile then sorts them into hosts that are not switched on, hosts that have no users, then hosts with users in lowest count first order
        membercount - places all the hosts that are off then all the hosts with zero users, then orders by age before adding hosts with members in lowest count first order
        image - builds an image list, displays it and asks which one to remove hosts for, then follows "oldest" but only for that image
#>

param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Parameter(Mandatory)]
    [int]$removeHostsCount = 0,
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

#Check if a valid value has been given for the removeHostsCount
if ($removeHostsCount -lt 0) {
    Write-Host "ERROR: Please specify a valid number of hosts to remove" -ForegroundColor Red
    exit 1
} elseif ($removeHostsCount -eq 0) {
    Write-Host "No hosts to remove - Exiting" -ForegroundColor Green
    exit 0
} 

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

#Get the host pool name and RG from the configuration
$hpRG = $localConfig.$localenv.desktops.avdstd.hostPoolRG
$hpName = $localConfig.$localenv.desktops.avdstd.hostPoolName


#Get the list of hosts associated with the host pool
$er = ""
$hosts = Get-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -ErrorVariable er
if ($er) {
    Write-Log "Unable to get Host Pool Hosts data for $hpRG / $hpName - permissions?" -logType fatal
    Write-Log "ERROR: $er" 
    exit 1
}

#Get the number of hosts in the pool
$existHostCount = $hosts.count
$newHostCount = $existHostCount - $removeHostsCount
if ($newHostCount -lt 0) {
    Write-Host "ERROR: Unable to remove that many hosts.  You can remove a maximum of $existHostCount" -ForegroundColor Red
    exit 1
}

#Display the number of hosts that will be removed as a confirmation
if ($removeHostsCount -gt 0) {
    Write-Host "This script will remove $removeHostsCount hosts from the host pool" -ForegroundColor Yellow
} else {
    Write-Host "No hosts to remove - Exiting" -ForegroundColor Green
    exit 0
}

#Get the hot pool host data
$hostData = Get-HostPoolHosts -RG $hpRG -hostPoolName $hpName
$hostList = $hostData.hostPoolData

if (-not $hostList) {
    Write-Host "ERROR: Unable to get the list of hosts in the host pool" -ForegroundColor Red
    exit 1
}

#This section sorts the information into hosts with users and hosts without, then from that list it sorts the hosts by age
#Host age sort
$hostList = [array]($hostList | Sort-Object -Property hostCreationTime)
$offHosts = [array]($hostList | Where-Object { $_.powerState -eq 'off' })
$onHosts = [array]($hostList | Where-Object { $_.powerState -eq 'on' })

#User sort
$onNoUsersHosts = ($onHosts | Where-Object { $_.connectedUsers -eq 0 })
$onHostWithUsers = ($onHosts | Where-Object { $_.connectedUsers -gt 0 })
$onHostWithUsersSorted = ($onHostWithUsers | Sort-Object -Property connectedUsers)    #Sorted least to most users

#Image sort
$imageList = $hostList | Sort-Object -Property hostImageVersion
$imageListUnique = $imageList | Select-Object -Unique hostImageVersion

#Set up the two lists - hosts with users and hosts without user.  Hosts without users will be actioned first.
$removeNoUserList = @{}
$removeWithUserList = @{}

#Build the delete list
$appendedHosts = $offHosts + $onNoUsersHosts

#check to make sure we have enough hosts in the list of hosts without users.  If we do, then just action from that list and leave users alone
if ($appendedHosts.count -ge $removeHostsCount) {
    Write-Host "Removing the following hosts (oldest first) - no hosts with users will be affected" -ForegroundColor Yellow
    $removeNoUserList = $appendedHosts | Select-Object -First $removeHostsCount
    $removeNoUserList | Select-Object hostPoolAndName,hostCreationTime,connectedUsers | Format-Table -AutoSize

} else {
    #So there are not enough hosts to remove without removing ones with users, so notify the person running the script
    Write-Host "Removing the following no-user hosts" -ForegroundColor Yellow
    $removeNoUserList = $appendedHosts
    $removeNoUserList | Select-Object hostPoolAndName,hostCreationTime,connectedUsers | Format-Table -AutoSize

    #There are not enough hosts to remove without removing ones with users
    Write-Host "Removing the following hosts - WARNING: these hosts have users currently logged in" -ForegroundColor Yellow
    Write-Host "These users will be sent a message and given 5 minutes to Log Off before being forcefully logged out"
    $removeWithUserList = $onHostWithUsersSorted | Select-Object -First ($removeHostsCount-$removeNoUserList.count)
    $removeWithUserList | Select-Object hostPoolAndName,hostCreationTime,connectedUsers | Format-Table -AutoSize
}


#Verify that the user want to indeed remove the hosts
if ($removeHostsCount -gt 0) {
    Write-Host "Are you sure you want to remove $removeHostsCount hosts from the host pool? (y/n)" -ForegroundColor Yellow
    if ($removeWithUserList.Count -gt 0) {
        write-host "WARNING: This will remove hosts with users currently logged in and will incur a 5 minute delay" -ForegroundColor Red
    }
    $answer = Read-Host
    if ($answer -ne "y") {
        Write-Host "Exiting" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "No hosts to remove - Exiting" -ForegroundColor Green
    exit 0
}

#this is where the action starts
#Check if there is a scale plan and disable it
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

#Give the users 5 mins to log off.
$logOffTime = (Get-Date).AddMinutes(5)

#If we are working with hosts that have users, set the host to drain mode and notify the user they have 5 mins to log off.
if ($removeWithUserList.count -gt 0) {
    Write-Host "Setting hosts with users to Drain Mode" -ForegroundColor Yellow
    foreach ($hpHost in $removeWithUserList) {
        Write-Host "Setting host: $($hpHost.hostName) to Drain Mode" -ForegroundColor Yellow
        if (-not $dryrun) {
            #Set the host to drain mode on
            Update-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -Name $hpHost.hostName -AllowNewSession:$false
        }

        #Notify each user on the host that they have 5 minutes to log off
        $users = Get-AzWvdUserSession -ResourceGroupName $hpRG -HostPoolName $hpName -SessionHostName $hpHost.hostName
        foreach ($user in $users) {
            Write-Host "Notifying user: $($user.ActiveDirectoryUserName) on host: $($hpHost.hostName) that they have 5 minutes to log off" -ForegroundColor Yellow
            if (-not $dryrun) {
                $sessionID = ($user.Name).split("/")[-1]
                #Send the user a notification message
                Send-AzWvdUserSessionMessage -ResourceGroupName $hpRG -HostPoolName $hpName -SessionHostName $hpHost.hostName -UserSessionId $sessionID -MessageBody "This host is being removed from service.  This host will terminate at $logOffTime.  Please log off now." -MessageTitle "Urgent Action Required"
            }
        }
    }
}

#while we are waiting for users to log off, remove any hosts and associated VMs that have no users or are logged off that have been identified for removal
foreach ($hpHost in $removeNoUserList) {
    Write-Host "Removing host: $($hpHost.hostName)" -ForegroundColor Yellow
    if (-not $dryrun) {
        #Remove the host from the hostpool
        Remove-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -Name $hpHost.hostName
        #Delete the virtual machine itself
        Get-AzVM -ResourceId $hpHost.vmResourceId | Remove-AzVM -Force
    }
}

#Back with the hosts with users, cycle through the hosts to check the users have loghged off as requested.  Keep doing this for 5 mins
#if the users to log off before the 5 mins is up, then then we can continue or after the 5 mins force a logoff.
if ($removeWithUserList.count -gt 0) {
    #Wait until the time is equal or greater than the logoff time
    $now = Get-Date
    $forceLogoff = $true
    while ($now -lt $logOffTime) {
        Write-Host "Waiting until $logOffTime or until all users log off" -ForegroundColor Yellow
        Start-Sleep -Seconds 60
        $userCount = 0
        #Check each host to see if users are still logged in
        foreach ($hpHost in $removeWithUserList) {
            $users = Get-AzWvdUserSession -ResourceGroupName $hpRG -HostPoolName $hpName -SessionHostName $hpHost.hostName
            $userCount += $users.count
        }
        #Check if we have any users still logged in.  If not, then  we can break out of the timer loop
        if ($userCount -eq 0) {
            Write-Host "All users have logged off" -ForegroundColor Green
            $forceLogoff = $false
            break
        } else {
            Write-Host " - There are still $userCount users logged on" -ForegroundColor Grey
        }
        $now = Get-Date
    }

    #Forcefully log out the users on each host (if required)
    if ($forceLogoff) {
        foreach ($hpHost in $removeWithUserList) {
            Write-Host "Forcing logoff of users on host: $($hpHost.hostName)" -ForegroundColor Yellow
            if (-not $dryrun) {
                $users = Get-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -Name $hpHost.hostName | Select-Object -ExpandProperty connectedUsers
                foreach ($user in $users) {
                    Write-Host "Forcing logoff of user: $($user.userName) on host: $($hpHost.hostName)" -ForegroundColor Yellow
                    Disconnect-AzWvdUserSession -ResourceGroupName $hpRG -HostPoolName $hpName -SessionHostName $hpHost.hostName -UserName $user.userName
                }
            }
        }
    }

    #Not that users have been logged out, remove the hosts from the hostpool and associated VMs
    foreach ($hpHostName in $removeWithUserList) {
        Write-Host "Removing host: $($hpHost.hostName)" -ForegroundColor Yellow
        if (-not $dryrun) {
            #Remove the host from the hostpool
            Remove-AzWvdSessionHost -ResourceGroupName $hpRG -HostPoolName $hpName -Name $hpHost.hostName
            #Delete the virtual machine itself
            Get-AzVM -ResourceId $hpHost.vmResourceId | Remove-AzVM -Force
        }
    }
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

Write-Host "Finished" -ForegroundColor Green


