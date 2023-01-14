# this script will deploy both a BUILD environment and test build AND a compute gallery.  For the dual compute gallery setup as shown in the README.MD
# below a second script and pipeline YAML file have also been included.


param (
    [Parameter(Mandatory)]
    [String]$localenv,
    [Bool]$dryrun = $true,
    [Bool]$dologin = $true,
    [Bool]$doTestFileUpload = $true
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

$out = New-AzSubscriptionDeployment -Name "CommonBuilderComponents" -Location $localConfig.$localenv.location -Verbose -TemplateFile ".\1_Common\deploy.bicep" -WhatIf:$dryrun -TemplateParameterObject @{
    localenv=$localenv
    location=$localConfig.$localenv.location
    tags=$localConfig.$localenv.tags
    blobContainerSoftware = $localConfig.general.repoSoftware
    RGImageName = $localConfig.$localenv.imageBuilderRGName
    productShortName = $localConfig.general.productShortName
}

$storageRepoName = $out.Outputs.storageRepoName.value
$storageRepoRG = $out.Outputs.storageRepoRG.value
$storageRepoSWC = $out.Outputs.storageRepoSoftwareContainer.value

# if (-not $storageRepoName) {
#     Write-Host "ERROR: Could not get the storage account name from the deployment - check for deployment errors" -ForegroundColor Red
#     exit 1
# }

if (-not $storageRepoSWC ) {
    Write-Host "ERROR: Could not get the storage account name from the deployment - check for deployment errors" -ForegroundColor Red
    exit 1
}

# #Upload the Test Software to the Image Builder Repo
# if ($doTestFileUpload) {
#     #Upload the Test repo files
#     Write-Host "Uploading the Test Repo Files to the Repository" -ForegroundColor Green

#     #Get the storage account context
#     $stShareContext = Get-AzStorageAccount -ResourceGroupName $storageRepoRG -Name $storageRepoName | Get-AzStorageShare -Name $storageRepoShare

#     if (-not $stShareContext) {
#         Write-Host "ERROR: Could not get the storage account context with share - check for deployment errors" -ForegroundColor Red
#         exit 1
#     }

#     $testSWFolder = $localConfig.general.testSWFolder

#     #Check to see if the test folder alrady exists
#     Write-Host " - Checking for existing $testSWFolder folder"
#     if (-not ($stShareContext | Get-AzStorageFile -Path $testSWFolder -ErrorAction SilentlyContinue)) {

#         #Create the Test Folder to upload the files to
#         Write-Host " - $testSWFolder not found - creating"
#         $stShareContext | New-AzStorageDirectory -Path $testSWFolder
#     }

#     #Copy the Test Files to the Repo
#     Get-ChildItem -Path ./Components/TestSoftware/* -Include *.exe,*.msi | Where-Object { $_.GetType().Name -eq "FileInfo"} | ForEach-Object {
#         Write-Host " - Uploading: $($_.FullName)"
#         Set-AzStorageFileContent -Share $stShareContext.CloudFileShare -Source $_.FullName -Path $testSWFolder -Force
#     }
# } else {
#     Write-Host "Test Files not uploaded to the Image Builder Repo" -ForegroundColor Yellow
# }

#Upload the Test Software to the Image Builder Repo
if ($doTestFileUpload) {
    #Upload the Test repo files
    Write-Host "Uploading the Test Repo Files to the Repository" -ForegroundColor Green

    #Get the storage account context
    $stSWContext = (Get-AzStorageAccount -ResourceGroupName $storageRepoRG -Name $storageRepoName | Get-AzStorageContainer -Name $storageRepoSWC).Context


    if (-not $stSWContext) {
        Write-Host "ERROR: Could not get the storage account context with container - check for deployment errors" -ForegroundColor Red
        exit 1
    }

    $testSWFolder = $localConfig.general.swContainer

    #Copy the Test Files to the Repo
    Get-ChildItem -Path ./Components/TestSoftware/* -Exclude *.MD,*.git* | Where-Object { $_.GetType().Name -eq "FileInfo"} | ForEach-Object {
        Write-Host " - Uploading: $($_.FullName)"
        Set-AzStorageBlobContent -Blob "$testSWFolder/$($_.Name)" -File $_.fullname -Container $storageRepoSWC -Context $stSWContext -Force
    }
} else {
    Write-Host "Test Files not uploaded to the Software Repo" -ForegroundColor Yellow
}

#Set-AzStorageBlobContent -Blob 'test/kdiff3-1.9.5-windows-64-cl.exe' -File 'C:\Development\QuberixBlog\2_2_ImageBuilder\Components\TestSoftware\kdiff3-1.9.5-windows-64-cl.exe' -Container $storageRepoSWC -Context $stSWContext -Force

Write-Host "Finished" -foregroundColor Green
