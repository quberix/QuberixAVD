#To be run on the AD Server

[CmdletBinding()]
param (
    [Bool]$installPreReqs = $false
)

if ($installPreReqs) {
    #Check if the PowershellGet module is installed and if not install it
    if (!(Get-Module -Name "PowershellGet")) {
        Write-Host "Installing PowershellGet module" -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-Module -Name "PowershellGet" -Force
    }

    #Check if the MSAL.PS module is installed and if not install it
    if (!(Get-Module -Name "MSAL.PS")) {
        Write-Host "Installing MSAL.PS module" -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-Module -Name "MSAL.PS" -Force
    }

    #Check if the Azure AD module is installed and if not install it
    if (!(Get-Module -Name "AzureAD")) {
        Write-Host "Installing AzureAD module" -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-Module -Name "AzureAD" -Force
    }

    Write-Host "PreReqs installed.  Now run the script again without the -installPreReqs parameter" -ForegroundColor Green
    exit 0
}

#Import the AAD Cloud Sync tools module once more
Import-module -Name "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Utility\AADCloudSyncTools" -Force

#Connect to the AAD Cloud Sync Tools
Connect-AADCloudSyncTools 

#Get the current status of the AAD Cloud Sync Tools
$syncStatus = Get-AADCloudSyncToolsJobStatus
$syncStatus