$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue';
$ErrorActionPreference = "Stop"

$script:hasFailed = $false

#Pull in the local library of functions
if ($runLocally) {
    import-module -Force "..\..\Components\BuildScriptsCommon\InstallSoftwareLibrary"
} else {
    import-module -Force "$PSScriptRoot\InstallSoftwareLibrary.psm1"
}

Write-Log "Running the Installer Script" -logtag "INSTALLER"

#Set a global - this is used to determine if any of the tests have failed
$script:hasFailed = $false

<#
    .SYNOPSIS
    Test the running of an expected command to ensure it exists and works as expected

    .INPUTS
    command - The command to test
    expectedExitCode - The expected exit code from the command (defaults to 0)

    .OUTPUTS
    True if the command succeeded, false if it failed

    .NOTES
    If any of the tests fail, the script will exit with a non-zero exit code
#>
function Test-Command {
    param (
        [ValidateNotNullOrEmpty()]
        [string]$command,
        [int]$expectedExitCode = 0,
        [string]$logTag = "VALIDATION-Command"
    )

    Write-Log "Testing: '$command'" -logtag $logTag

    ($command | Invoke-Expression) | Write-Verbose
    if ($LASTEXITCODE -ne $expectedExitCode) {
        Write-Log "Test '$command' failured. Exit code was $LASTEXITCODE when $expectedExitCode is expected" -logtag $logTag -loglevel "ERROR"
        $script:hasFailed = $true
    }
    else {
        Write-Log "Test '$command' succeeded" -logtag $logTag
    }
}

#Start the Validation Run
$logTag = "VALIDATION"
Write-Log "Performing Validation Tests" -logtag $logTag

#Test to make sure the commands are installed and work as expected
Test-Command "code --version"
Test-Command "git --version"

#Add in any other tests here

#If any fail, kill the build
if ($script:hasFailed) {
    Write-Log "Validation tests failed" -logtag $logTag -loglevel "ERROR"
    exit 1
}
else {
    Write-Log "Validation tests succeeded!" -logtag $logTag
}