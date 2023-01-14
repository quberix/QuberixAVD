# this script will deploy both a BUILD environment and test build AND a compute gallery.  For the dual compute gallery setup as shown in the README.MD
# below a second script and pipeline YAML file have also been included.


param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [Bool]$installModules = $false,
    [Bool]$buildImage = $true
)

#Check to make sure the image builder powershell modules are in place
if ($installModules) {
    Write-Host "Checking for Image Builder Powershell Module" -ForegroundColor Green
    Install-Module Az.ImageBuilder -force
}

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

#CHECK USER ENVIRONMENT
#Check if the User Managed ID exists for the Image builder and if not Create It.
$imageBuilderUserName = $localConfig.$localenv.imageBuilderUserName
$imageBuilderRG = $localConfig.$localenv.imageBuilderRGName
$imageBuilderRGRoleName = $localConfig.general.imageBuilderRoleName

Write-Host "Checking for User Assigned Managed Identity '$imageBuilderUserName'" -ForegroundColor Green
$builderUID = Get-AzUserAssignedIdentity -ResourceGroupName $imageBuilderRG -Name $imageBuilderUserName -ErrorVariable userNotPresent -ErrorAction SilentlyContinue
if ($userNotPresent) {
    Write-Host " - Creating missing User Assigned Managed Identity '$imageBuilderUserName'"
    if (-not $dryrun) {
        $builderUID = New-AzUserAssignedIdentity -ResourceGroupName $imageBuilderRG -Location $localConfig.$localenv.location -Name $imageBuilderUserName -Tag $tags
    } else {
        write-host "DRYRUN: Cannot continue past this point as UMI is required" -ForegroundColor Red
        exit 1
    }
    Write-Host " - Created '$imageBuilderUserName' ($($builderUID.PrincipalId))"
}
else {
    Write-Host " - User Assigned Managed Identity '$imageBuilderUserName' already exists ($($builderUID.PrincipalId))"
}

#Grant UMI contributor access to the compute gallery - ideally we should create a custom role for this as all it needs is read/write/delete on the gallery
Write-Host "Granting the Image Builder User Managed Identity access to the compute gallery ($imageBuilderRG = $imageBuilderRGRoleName)" -ForegroundColor Green
$builderCGAssign = Get-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderRGRoleName -ResourceGroupName $imageBuilderRG
if (-not $builderCGAssign) {
    Write-Information " - Assigning Image Builder Role '$imageBuilderRGRoleName' to '$imageBuilderUserName'"
    if (-not $dryrun) {
        New-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderRGRoleName -ResourceGroupName $imageBuilderRG
    }
}
else {
    Write-Information " - '$imageBuilderUserName' has already been assigned '$imageBuilderRGRoleName'"
}

#Grant the UMI access to the storage account blob container for scripts access
$storageRepoRG = $localConfig.$localenv.repoRG
$storageRepoName = $localConfig.$localenv.repoStorageName
$imageBuilderScriptRoleName = $localConfig.general.imageBuilderScriptRoleName
$storageScriptContainer = $localConfig.general.scriptContainer

Write-Host "Granting the Image Builder User Managed Identity access to the storage account scripts container ($storageScriptContainer = $imageBuilderScriptRoleName)" -ForegroundColor Green
$stContext = Get-AzStorageAccount -ResourceGroupName $storageRepoRG -Name $storageRepoName
$builderScriptAssign = Get-AzRoleAssignment -ObjectId $builderUID.PrincipalId -RoleDefinitionName $imageBuilderScriptRoleName -Scope "$($stContext.Id)/default/$storageScriptContainer"
if (-not $builderScriptAssign) {
    Write-Information " - Assigning Image Builder Role '$imageBuilderScriptRoleName' to '$imageBuilderUserName'"
    if (-not $dryrun) {
        New-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderScriptRoleName -Scope "$($stContext.Id)/default/$storageScriptContainer"
    }
}
else {
    Write-Information " - '$imageBuilderUserName' has already been assigned '$imageBuilderScriptRoleName'"
}

#Grant the UMI access to the storage account blob container for software repository access
$storageRepoRG = $localConfig.$localenv.repoRG
$storageRepoName = $localConfig.$localenv.repoStorageName
$imageBuilderSWRepoRoleName = $localConfig.general.imageBuilderSWRepoRoleName
$storageSWContainer = $localConfig.general.swContainer

Write-Host "Granting the Image Builder User Managed Identity access to the storage account software container ($storageSWContainer = $imageBuilderSWRepoRoleName)" -ForegroundColor Green
$stContext = Get-AzStorageAccount -ResourceGroupName $storageRepoRG -Name $storageRepoName
$builderSWAssign = Get-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderSWRepoRoleName -Scope "$($stContext.Id)/default/$storageSWContainer"
if (-not $builderSWAssign) {
    Write-Information " - Assigning Image Builder Role '$imageBuilderSWRepoRoleName' to '$imageBuilderUserName'"
    if (-not $dryrun) {
        New-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderSWRepoRoleName -Scope "$($stContext.Id)/default/$storageSWContainer"
    }
}
else {
    Write-Information " - '$imageBuilderUserName' has already been assigned '$imageBuilderSWRepoRoleName'"
}

# #Grant the UMI access to the file share for scripts access (needs to access install files)
# Write-Host "Granting the Image Builder User Managed Identity access to the storage account software files repo" -ForegroundColor Green
# $imageBuilderShareRoleName = $localConfig.general.imageBuilderFileRoleName

# $stShareContext = Get-AzStorageAccount -ResourceGroupName $storageRepoRG -Name $storageRepoName
# $builderShareContrib = Get-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderShareRoleName -Scope "$($stShareContext.Id)" #-Scope "$($stShareContext.Id)/$($localConfig.general.repoShare)"
# if (-not $builderShareContrib) {
#     Write-Information " - Assigning Image Builder Role '$imageBuilderShareRoleName' to '$imageBuilderUserName'"
#     if (-not $dryrun) {
#         New-AzRoleAssignment -ObjectId $builderUID.PrincipalId  -RoleDefinitionName $imageBuilderShareRoleName -Scope "$($stShareContext.Id)" #-Scope "$($stShareContext.Id)/$($localConfig.general.repoShare)"
#     }
# }
# else {
#     Write-Information " - '$imageBuilderUserName' has already been assigned '$imageBuilderBlobRoleName'"
# }

#UPLOAD REQUIRED SCRIPTS
#Upload the build scripts to the Repo storage account blob/buildscripts container
Write-Host "Uploading the Build Scripts to the Repository" -ForegroundColor Green

#Get the storage account context
$stContainerContext = Get-AzStorageAccount -ResourceGroupName $storageRepoRG -Name $storageRepoName | Get-AzStorageContainer -Name $storageScriptContainer

if (-not $stContainerContext) {
    Write-Host "ERROR: Could not get the storage account context with container - check for deployment errors" -ForegroundColor Red
    exit 1
}

$buildScriptsFolder = ".\2a_SingleEnv\BuildScripts"
$buildfScriptsCommonFolder = "./$($localConfig.general.buildScriptsCommonFolder)"

#Check to see if the local build Scripts folder exists locally
if (-not (Test-Path $buildScriptsFolder)) {
   Write-Host "ERROR: Could not find the local build scripts folder - build scripts are required for deployment.  Check path and try again" -ForegroundColor Red
   Write-Host " - Path: $buildScriptsFolder"
   exit 1
}

#Check to see if the common/shared build Scripts folder exists locally
if (-not (Test-Path $buildfScriptsCommonFolder)) {
   Write-Host "ERROR: Could not find the common/shared build scripts folder - build scripts are required for deployment.  Check path and try again" -ForegroundColor Red
   Write-Host " - Path: $buildfScriptsCommonFolder"
   exit 1
}

#Pull all the files together into a single zip file
Write-Host " - Pulling files together into a single Zip file for upload"
$compressError = $null
$compress = @{
    Path = "$buildScriptsFolder\\*", "$buildfScriptsCommonFolder\\*"
    CompressionLevel = 'Fastest'
    DestinationPath = "$($env:TEMP)\\buildscripts.zip"
    Force = $true
}
Compress-Archive @compress -ErrorVariable compressError
if ($compressError) {
    Write-Host "ERROR: There was an error compressing the build scripts.  Check the error" -ForegroundColor Red
    Write-Host " - Error: $($compressError[0].Exception.Message)"
    exit 1
}

#Check to see if the new zip file exists
if (-not (Test-Path "$($env:TEMP)\buildscripts.zip")) {
   Write-Host "ERROR: Could not find the new zip file - build scripts are required for deployment.  Check the output from the file compression" -ForegroundColor Red
   Write-Host " - Path: $($env:TEMP)\buildscripts.zip"
   exit 1
}

#Upload the zip file to the blob container
$uploadError = $null
Write-Host " - Uploading: $($env:TEMP)\buildscripts.zip"
$stContainerContext | Set-AzStorageBlobContent -File "$($env:TEMP)\buildscripts.zip" -Force -ErrorVariable uploadError

if ($uploadError) {
    Write-Host "ERROR: There was an error uploading the build scripts to the repository.  Check the error and try again" -ForegroundColor Red
    Write-Host " - Error: $uploadError"
    exit 1
}

#THE BUILD
#Build the Gallery Definition and set up the image for building - the outputs from this are needed for the rest of the deployment
Write-Host "Deploying the Image Definition in preparation for building" -ForegroundColor Green
$defDeploy = $null
$out = New-AzSubscriptionDeployment -Name "singleImageBuilder" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\2a_SingleEnv\deploy.bicep" -ErrorVariable defDeploy -WhatIf:$dryrun -TemplateParameterObject @{
    localenv=$localenv
    location=$localConfig.$localenv.location
    tags=$localConfig.$localenv.tags
    owner=$localConfig.general.owner
    productShortName=$localConfig.general.product
    RGImageName=$imageBuilderRG
    userAssignedName=$imageBuilderUserName
    userAssignedRG=$imageBuilderRG
    repoName=$storageRepoName
    repoRG=$storageRepoRG
    imageName=$localConfig.general.desktopImageName
    replicationRegions=@()
}

if ($defDeploy) {
    Write-Host "ERROR: Failed to deploy the Image Definition" -ForegroundColor Red
    exit 1
}

$templateName = $out.Outputs.imageTemplateName.Value

Write-Host "Removing the old templates - this will run in the background" -ForegroundColor Green
#Clear out any previous build template to tidy up - only leave the one we have just created
#Get the list of image builder templates
$templates = Get-AzImageBuilderTemplate -ResourceGroupName $imageBuilderRG
#Loop through the templates and delete any that are not the current one
foreach ($template in $templates) {
    if ($template.Name -ne $templateName) {
        Write-Host " - Deleting old template $($template.Name)"
        Remove-AzImageBuilderTemplate -ResourceGroupName $imageBuilderRG -Name $template.Name -NoWait
    }
}

if ($buildImage) {
    #Now start the process of building the image
    Write-Host ""
    Write-Host "The image is now building.  This might take a while." -ForegroundColor Green
    Write-Host " - This script will continue to poll the image to check on progress.  You can quit the script if you wish."
    Write-Host " - If you quit the script use the portal or the following command to check on progress:"
    Write-Host "    Get-AzImageBuilderTemplate -ImageTemplateName '$templateName' -ResourceGroupName '$imageBuilderRG' | Select-Object LastRunStatusRunState, LastRunStatusRunSubState, LastRunStatusMessage"
    Write-Host ""

    $start = Get-Date
    Write-Host "Build Started: $now" -ForegroundColor Green

    #Kick off the image builder
    Start-AzImageBuilderTemplate -ResourceGroupName $imageBuilderRG -Name $templateName -NoWait

    #while loop that will poll the get-azimagebuildertemplate command until ProvisioningState is Succeeded or Failed
    while ($true) {
        $count++
        $image = Get-AzImageBuilderTemplate -ImageTemplateName $templateName -ResourceGroupName $imageBuilderRG
        if ($image.LastRunStatusRunState -eq 'Succeeded') {
            Write-Host "Image build succeeded" -ForegroundColor Green
            break
        }
        elseif ($image.LastRunStatusRunState -eq 'Failed') {
            Write-Host "Image build failed" -ForegroundColor Red
            Write-Host " - Error Message: $($image.LastRunStatusMessage)"
            Write-Host " - Check the Storage account in the Staging RG for more information:"
            Write-Host "   - RG: $($image.ExactStagingResourceGroup)"
            break
        }
        else {
            Write-Host "Image build is still running.  Polling again in 30 seconds: $($image.LastRunStatusRunState) - $($image.LastRunStatusRunSubState)" -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        }
    }
    $timespan = new-timespan -start $start -end (get-date)
    Write-Host "Image build ended after: $($timespan.Hours) hours, $($timespan.Minutes) minutes, $($timespan.Seconds) seconds"

    #Perhaps add a download of the packer log here rather than making the user go to the portal to acquire it.
}

Write-Host "Finished" -foregroundColor Green
