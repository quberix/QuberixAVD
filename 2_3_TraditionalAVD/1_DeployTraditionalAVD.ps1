param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [Bool]$deployHostPool = $true,
    [Bool]$deployHosts = $true,
    [Bool]$deployScaler = $true
)

#Import the central powershell configuration module
Import-Module ../PSConfig/deployConfig.psm1 -Force

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

#Deploy the bicep using a subscription based deployment
if ($dryrun) {
    Write-Host "DRYRUN: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Yellow
} else {
    Write-Host "LIVE: Running the Infrastructure Build - Deploying Resources" -ForegroundColor Green
}

#Deploy baseline infra and the hostpool
if ($deployHostPool) {
    Write-Host "Deploying the Host Pool and supporting infrastructure" -ForegroundColor Green
    $er = ""
    $out1 = New-AzSubscriptionDeployment -Name "StandardAVDHostPoolDeployment" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\1_hostpool.bicep" -WhatIf:$dryrun -ErrorVariable er -TemplateParameterObject @{
        localenv=$localenv
        location=$localConfig.$localenv.location
        tags=$localConfig.$localenv.tags
        productShortName = $localConfig.general.productShortName
        adDomainName = $localConfig.general.ADDomain
        adServerIPAddresses = @($localConfig.$localenv.ADStaticIpAddress)
        galleryImageName = $localConfig.$localenv.desktops.avdstd.image
        avdVnetName = $localConfig.$localenv.desktops.avdstd.vnetName
        avdVnetCIDR = $localConfig.$localenv.desktops.avdstd.vnetCIDR
        avdSubnetName = $localConfig.$localenv.desktops.avdstd.snetName
        avdSubnetCIDR = $localConfig.$localenv.desktops.avdstd.snetCIDR
        avdNSGName = $localConfig.$localenv.desktops.avdstd.nsgName
        hostpoolName = $localConfig.$localenv.desktops.avdstd.hostPoolName
        RGAVDName = $localConfig.$localenv.desktops.avdstd.hostPoolRG
        hostPoolHostNamePrefix = $localConfig.$localenv.desktops.avdstd.prefix
        hostPoolRDPProperties = $localConfig.$localenv.desktops.avdstd.rdpProperties
        hostPoolAppGroupName = $localConfig.$localenv.desktops.avdstd.appGroupName
        hostPoolWorkspaceName = $localConfig.$localenv.desktops.avdstd.workspaceName
    }

    if ($er) {
        Write-Host "ERROR: Failed to deploy the hostpool" -ForegroundColor Red
        #Write-Host $er
        exit 1
    } else {
        Write-Host "Hostpool deployed successfully" -ForegroundColor Green
    }
}

#Deploy the Hosts into the Hostpool
if ($deployHosts) {
    #Generate a host pool token for this deployment
    Write-Host "Generate a new host pool token" -ForegroundColor Green
    $hpRG = $localConfig.$localenv.desktops.avdstd.hostPoolRG
    $hpName = $localConfig.$localenv.desktops.avdstd.hostPoolName
    $expiryTime = $((Get-Date).ToUniversalTime().AddHours(8).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
    $hpToken = (New-AzWvdRegistrationInfo -HostPoolName $hpName -ResourceGroupName $hpRG -ExpirationTime $expiryTime).token
    
    if (-not $hpToken) {
        Write-Host "ERROR: Unable to generate a new host pool token" -ForegroundColor Red
        exit 1
    }
    

    Write-Host "Deploying the Virtual Machines and joining them to the hostpool" -ForegroundColor Green
    $er = ""
    $out2 = New-AzSubscriptionDeployment -Name "StandardAVDHostsDeployment" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\2_hosts.bicep" -WhatIf:$dryrun -ErrorVariable er -TemplateParameterObject @{
        localenv=$localenv
        location=$localConfig.$localenv.location
        tags=$localConfig.$localenv.tags
        productShortName = $localConfig.general.productShortName
        adDomainName = $localConfig.general.ADDomain
        adOUPath = $localConfig.$localenv.desktops.avdstd.ou
        avdVnetName = $localConfig.$localenv.desktops.avdstd.vnetName
        avdSubnetName = $localConfig.$localenv.desktops.avdstd.snetName
        hostpoolName = $hpName
        hostPoolRG = $hpRG
        galleryImageName = $localConfig.$localenv.desktops.avdstd.image
        hostPoolHostNamePrefix = $localConfig.$localenv.desktops.avdstd.prefix
        hostPoolToken = $hpToken
        hostPoolHostsToCreate = 2
        hostPoolHostsCurrentInstances = 0
    }

    if ($er) {
        Write-Host "ERROR: Failed to deploy the hostpool" -ForegroundColor Red
        #Write-Host $er
        exit 1
    } else {
        Write-Host "Hostpool deployed successfully" -ForegroundColor Green
    }
}

#Deploy the Scaling Plan (if required) to the hostpool
if ($deployScaler) {
    Write-Host "Deploying the Host Pool Azure Scaling Plan" -ForegroundColor Green

    Write-Host "Check that the azure scaling service has access to AVD (this is at subscription level - required)" -ForegroundColor Green

    #Check of the role has already been applied at subscription scope
    $result =  Get-AzRoleAssignment -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" -Scope /subscriptions/$subId -ErrorAction SilentlyContinue

    if (-not $result) {
        Write-Host "Assigning 'Scaling plan Desktop Virtualization Power On Off Contributor' rights on hostpool" -ForegroundColor Green
        Write-Host " - Note: this has to be assigned at subscrition level" -ForegroundColor Yellow
        #Get the tenent wide App ID for the AVD service
        $avdAppID = (Get-AzADServicePrincipal -AppId "9cdead84-a844-4324-93f2-b2e6bb768d07").Id
        #Assign the role
        New-AzRoleAssignment -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" -ObjectId $avdAppID -Scope /subscriptions/$subId
    }

    Write-Host "Deploying the scaling plan and associating with the hostpool" -ForegroundColor Green
    $er = ""
    $out3 = New-AzSubscriptionDeployment -Name "StandardAVDScalersDeployment" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\3_scalingplan.bicep" -WhatIf:$dryrun -ErrorVariable er -TemplateParameterObject @{
        localenv=$localenv
        location=$localConfig.$localenv.location
        tags=$localConfig.$localenv.tags
        productShortName = $localConfig.general.productShortName
        hostpoolName = $localConfig.$localenv.desktops.avdstd.hostPoolName
        hostPoolRG = $localConfig.$localenv.desktops.avdstd.hostPoolRG
    }

    if ($er) {
        Write-Host "ERROR: Failed to deploy the hostpool" -ForegroundColor Red
        #Write-Host $er
        exit 1
    } else {
        Write-Host "Hostpool deployed successfully" -ForegroundColor Green
    }
}

Write-Host "Finished Deployment" -foregroundColor Green

Write-Host "In order to log into AVD, go here: https://client.wvd.microsoft.com/arm/webclient/index.html"
Write-Host "Remember that in order to log in you will need to add a user to the Application Group"
Write-Host ""