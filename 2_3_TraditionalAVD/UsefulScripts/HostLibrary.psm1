<#
.SYNOPSIS
    A function that gets the information about each host in the pool including some common stats about all the hosts
#>
function Get-HostPoolHosts {
    param (
        [string]$RG,
        [string]$hostPoolName
    )

    #$hostsPoolData = @{}
    $hostsPoolData = @()
    $returnData = @{}

    $hostsTurnedOff = @()

    Write-Host "Processing Host Pool Hosts Data - $RG / $hostPoolName" -ForegroundColor Gray

    #Get the list of session hosts
    $er = ""
    $hosts = Get-AzWvdSessionHost -ResourceGroupName $RG -HostPoolName $hostPoolName -ErrorVariable er
    if ($er) {
        Write-Host "Unable to get Host Pool Hosts data for $RG / $hostPoolName - permissions?" -ForegroundColor Red
        Write-Host "ERROR: $er" 
        exit 1
    }

    $countHost = 0
    $countDrainModeOn = 0
    $countStatusIsNotAvailable = 0

    Write-Host "Processing Host Pool Hosts Data - Hosts: $hosts" -ForegroundColor Gray

    #Get the list of active hosts
    if ($hosts) {
        #Step trhough each host
        foreach ($hostobject in $hosts) {
            $hostData = @{}
            $countHost ++

            #Get the host and pool name data
            $hostData["hostPoolAndName"] = $hostobject.Name
            $hostData["hostName"] = ((($hostobject.Name).split('/'))[-1]).Trim()     #Get the last element in the array

            #Determine whether users can join it
            $hostData["userCanJoin"] = $hostobject.AllowNewSession
            if (-not $hostData["userCanJoin"]) {
                $countDrainModeOn++
            }

            #Get the heartbeat, state and host status
            $hostData["hostLastHeartbeat"] = $hostobject.LastHeartBeat
            $hostData["hostUpdateState"] = $hostobject.UpdateState
            $hostData["hostLastErrorMessage"] = $hostobject.UpdateErrorMessage
            $hostData["hostStatus"] = $hostobject.Status
            if ($hostData["hostStatus"] -ne "Available") {
                $countStatusIsNotAvailable ++
                $hostsTurnedOff += $hostData["hostName"]
            }

            #Get the sessions and resource id informaiton
            $hostData["sessions"] = $hostobject.Session
            $hostData["VMResourceID"] = $hostobject.resourceId
            $hostData["connectedUsers"] = $hostData["sessions"]
            
            #Delve deeper into the VM's themselves and get the VM data
            $vmInfo = Get-AZVM -ResourceId $hostData["VMResourceID"]

            #Store the VM specific details
            $hostData["hostCreationTime"] = $vmInfo.TimeCreated
            $hostData["hostImageVersion"] = $vmInfo.StorageProfile.ImageReference.ExactVersion
            $hostData["hostImagePublisher"] = $vmInfo.StorageProfile.ImageReference.Publisher
            $hostData["hostImageOffer"] = $vmInfo.StorageProfile.ImageReference.Offer
            $hostData["hostImageSKU"] = $vmInfo.StorageProfile.ImageReference.Sku
            $hostData["hostImageName"] = $vmInfo.StorageProfile.ImageReference.Version
            $hostData["hostImageResourceID"] = $vmInfo.StorageProfile.ImageReference.Id

            #Get the power state of the VM
            $powerState = (Get-AzVM -ResourceId $hostData["VMResourceID"] -Status).Statuses[1].displayStatus
            if ($powerstate -eq "VM running") {
                $hostdata["powerState"] = "on"
            } elseif ($powerstate -eq "VM deallocated") {
                $hostdata["powerState"] = "off"
            } else {
                $hostdata["powerState"] = "unknown"
            }

            $hostsPoolData += $hostData

        }
        Write-Host "Host pool $($hostData["hostName"]) has: $countDrainModeOn in drain mode, $countStatusIsNotAvailable where status is not 'Available'" -ForegroundColor Gray

    } else {
        Write-Host "There are no hosts" -ForegroundColor gray
    }

    #Store a sewt of common hostpool stats
    $returnData["hostCount"] = $countHost
    $returnData["hostsActiveCount"] = $countHost - $countDrainModeOn - $countStatusIsNotAvailable
    $returnData["hostsInDrainModeCount"] = $countDrainModeOn
    $returnData["hostsWithStatusNotAvailableCount"] = $countStatusIsNotAvailable
    $returnData["hostPoolData"] = $hostsPoolData
    $returnData["poolName"] = $hostPoolName
    $returnData["poolRG"] = $RG

    Write-Host "Found $countHost hosts in hostpool" -ForegroundColor Gray

    return $returnData
}


<#
.SYNOPSIS
    Determine whether a host pool has a scaling plan
#>
function Get-HostPoolScalingPlanExists {
    Param (
        [string]$hostPoolName,
        [string]$hostPoolRG
    )

    $scalePlan = Get-AzWvdScalingPlan -ResourceGroupName $hostPoolRG -HostPoolName $hostPoolName -ErrorVariable er -ErrorAction SilentlyContinue
    if (-not $er) {
        Write-Host "Scale plan found.  Current enabled state is $($scalePlan.HostPoolReference.ScalingPlanEnabled)" -ForegroundColor Gray
        return $true
    } else {
        return $false
    }
}


<#
.SYNOPSIS
    Get the current state of the scaling plan
#>
function Get-HostPoolScalingPlanState {
    Param (
        [string]$hostPoolName,
        [string]$hostPoolRG
    )

    $scalePlan = Get-AzWvdScalingPlan -ResourceGroupName $hostPoolRG -HostPoolName $hostPoolName -ErrorVariable er -ErrorAction SilentlyContinue
    if (-not $er) {
        Write-Host "Scale plan found.  Current enabled state is $($scalePlan.HostPoolReference.ScalingPlanEnabled)" -ForegroundColor Gray
        $scalePlanState = [bool]$scalePlan.HostPoolReference.ScalingPlanEnabled
        return $scalePlanState
    } else {
        return $false
    }
}

<#
.SYNOPSIS
    Sets the state of the scaling plan of a specified hostpool to either enable or disabled (true or false)
#>
function Set-HostPoolScalingPlanState {
    Param (
        [string]$hostPoolName,
        [string]$hostPoolRG,
        [bool]$enabled
    )

    #Get the scaling plan
    $scalePlan = Get-AzWvdScalingPlan -ResourceGroupName $hostPoolRG -HostPoolName $hostPoolName -ErrorVariable er -ErrorAction SilentlyContinue
    if (-not $er) {
        Write-Host "Scale plan found.  Current enabled state is $($scalePlan.HostPoolReference.ScalingPlanEnabled)" 
        $scalePlanState = [bool]$scalePlan.HostPoolReference.ScalingPlanEnabled

        if ($scalePlanState -eq $enabled) {
            Write-Host "Scale plan state is already set to $enabled" -ForegroundColor Gray
        } else {
            #Scaling plans had a host pool reference list (they can be attached to more than one)
            #Determine the correct hostpool and rebuild that list to reflect the state of only the required hostpool leaving
            #all the other hostpool references as they were.
            $newHPReference = @()
            foreach ($planHP in $scalePlan.HostPoolReference) {
                $hpArmPath = $planHP.HostPoolArmPath
                if ($hpArmPath.split('/')[-1] -eq $hpName) {
                    $planHP.ScalingPlanEnabled = $false
                }
                $newHPReference += $planHP
            }
            #Update the scaling plan
            $scalePlan | Update-AZWvdScalingPlan -HostPoolReference $newHPReference
        }
    }

    #Do a check to make sure the state has taken
    $scalePlan = Get-AzWvdScalingPlan -ResourceGroupName $hostPoolRG -HostPoolName $hostPoolName -ErrorVariable er -ErrorAction SilentlyContinue
    if (-not $er) {
        $scalePlanState = [bool]$scalePlan.HostPoolReference.ScalingPlanEnabled
        if ($scalePlanState -eq $enabled) {
            Write-Host "Scale plan state is now set to $enabled" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "Scale plan state is still set to $scalePlanState" -ForegroundColor Red
            return $false
        }

    }
}

#Export the functions
Export-ModuleMember -Function Get-HostPoolHosts
Export-ModuleMember -Function Get-HostPoolScalingPlanExists
Export-ModuleMember -Function Get-HostPoolScalingPlanState
Export-ModuleMember -Function Set-HostPoolScalingPlanState