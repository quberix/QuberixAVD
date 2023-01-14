param (
    [Parameter(Mandatory)]
    [String]$domainName,
    [String]$domainMode = "WinThreshold",
    [String]$forestMode = "WinThreshold"
)

#NOTES:
#Need to add some checks around this script to ensure that the nodules have installed correctly, the domain name is valid
#and a password has been provided for SafeMode

Write-Output "Installing Active Directory Domain Services Powershell Modules"
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 
Import-Module ADDSDeployment

#Generate a random password for the SafeModeAdmin as it is not needed for temp deployments like this.
#Ideally it should be passed in or stored in the vault.
$secPwd = ConvertTo-SecureString (-join([char[]](33..122) | Get-Random -Count 20)) -AsPlainText -Force

Write-Output "Creating Active Directory Forest"
Install-ADDSForest `
    -DomainName $domainName `
    -InstallDNS:$true `
    -DomainMode $domainMode `
    -ForestMode $forestMode `
    -Force:$true `
    -SafeModeAdministratorPassword $secPwd `
    -NoRebootOnCompletion:$true