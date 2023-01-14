function Get-Config {

    $owner = "Quberatron"
    $product = "QBX"
    $ADBaseDesktopOU = 'OU=Desktops,DC=quberatron,DC=com'

    $config = @{
        dev = @{
            tags = @{
                Environment="DEV"
                Owner=$owner
                Product=$product
            }
            subscriptionID = "8eef5bcc-4fc3-43bc-b817-048a708743c3"
            subscriptionName = "CORE DEV"
            location = "uksouth"
            boundaryVnetCIDR = "10.245.0.0/24"
            boundaryVnetBastionCIDR = '10.245.0.0/26'
            idVnetCIDR = '10.245.8.0/24'
            idSnetADCIDR = '10.245.8.0/27'
            ADStaticIpAddress = '10.245.8.20'
            VMADAutoShutdownTime = '1900'
            imageBuilderUserName = "$product-imagebuilder-dev".ToLower()
            imageBuilderRGName = "$product-RG-IMAGES-DEV".ToUpper()
            repoRG = "$product-RG-IMAGES-DEV".ToUpper()
            repoStorageName = "$($product)stbuilderrepodev".ToLower()
            desktops = @{
                avdstd = @{
                    prefix = "qbxavdstdd"
                    ou = "OU=DEV,OU=AVDStd,$($ADBaseDesktopOU)"
                    image = "QBXDesktop"
                    rdpProperties = "audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;compression:i:1;videoplaybackmode:i:1;redirectlocation:i:0;redirectwebauthn:i:1;use multimon:i:1;dynamic resolution:i:1"
                    hostPoolName = "$($product)-hp-avdstd-dev".ToLower()
                    hostPoolRG = "$product-RG-AVD-STD-DEV".ToUpper()
                    vnetName = "$product-vnet-avdstd-dev".ToLower()
                    vnetCIDR = '10.245.16.0/24'
                    snetName = "$product-snet-avdstd-dev".ToLower()
                    snetCIDR = '10.245.16.0/24'
                    nsgName = "$product-nsg-avdstd-dev".ToLower()
                    appGroupName = "$product-ag-avdstd-dev".ToLower()
                    workspaceName = "$product-ws-avdstd-dev".ToLower()
                }
            }
        }

        prod = @{
            tags = @{
                Environment="PROD"
                Owner=$owner
                Product=$product
            }
            subscriptionID = "ea66f27b-e8f6-4082-8dad-006a4e82fcf2"
            subscriptionName = "CORE PROD"
            location = "uksouth"
            boundaryVnetCIDR = "10.246.0.0/24"
            boundaryVnetBastionCIDR = '10.246.0.0/26'
            idVnetCIDR = '10.246.8.0/24'
            idSnetADCIDR = '10.246.8.0/27'
            ADStaticIpAddress = '10.246.8.20'
            VMADAutoShutdownTime = '1900'
            imageBuilderUserName = "$product-imagebuilder-prod".ToLower()
            imageBuilderRGName = "$product-RG-IMAGES-PROD".ToUpper()
            repoRG = "$product-RG-IMAGES-PROD".ToUpper()
            repoStorageName = "$($product)stbuilderrepoprod".ToLower()
            desktops = @{
                avdstd = @{
                    prefix = "qbxavdstdd"
                    ou = "OU=PROD,OU=AVDStd,$($ADBaseDesktopOU)"
                    image = "QBXDesktop"
                    rdpProperties = "audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;compression:i:1;videoplaybackmode:i:1;redirectlocation:i:0;redirectwebauthn:i:1;use multimon:i:1;dynamic resolution:i:1"
                    hostPoolName = "$($product)-hp-prod".ToLower()
                    hostPoolRG = "$product-RG-AVD-STD-PROD".ToUpper()
                    vnetName = "$product-vnet-avdstd-prod".ToLower()
                    vnetCIDR = '10.246.16.0/24'
                    snetName = "$product-snet-avdstd-prod".ToLower()
                    snetCIDR = "'10.246.16.0/24'"
                    nsgName = "$product-nsg-avdstd-prod".ToLower()
                    appGroupName = "$product-ag-avdstd-prod".ToLower()
                    workspaceName = "$product-ws-avdstd-prod".ToLower()
                }
            }
        }

        general = @{
            tenantID = "b97e741f-846c-46ce-ba46-2d2dcf9abc38"
            ADDomain = 'quberatron.com'
            ADUsername = 'commander'
            ADForestScript = 'scripts/CreateForest.ps1'
            repoSoftware = 'repository'
            scriptContainer = 'buildscripts'
            swContainer = 'TestSoftware'
            imageBuilderRoleName = "Contributor"
            imageBuilderScriptRoleName = "Storage Blob Data Contributor"
            imageBuilderSWRepoRoleName = "Storage Blob Data Reader"
            buildScriptsCommonFolder = "Components/BuildScriptsCommon"
            desktopImageName = "QBXDesktop"
            owner = $owner
            product = $product
            productShortName = $product
            rdpProperties = ''
        }
    }

    return $config
}

Export-ModuleMember -Function Get-Config
