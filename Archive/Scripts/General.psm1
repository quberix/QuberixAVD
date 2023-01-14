# A library providing config and common elements for the deployment scripts
function Get_Environment_Config {
    param (
        [Parameter(Mandatory)]
        [string]$localenv
    )

    #General tags to apply to resources
    $RGTags = @(
        "Criticality=Tier 3",
        "Environment=$localenv".ToUpper(),
        "Owner=QBX",
        "Product=QBX"
    )

    $environments = @{
        "dev" = @{
            "subscriptionID" = "7c235ed2-aade-4f4c-a9d3-78f332fb5aee"
            "subscriptionName" = "UDAL Training"
            "location" = "uksouth"
            "orgCode" = "QBX"
            "coreRG" = "QBX-RG-CORE-DEV"
            "adRG" = "QBX-RG-AD-DEV"
            "tags" = $RGTags
        }
        "prod" = @{
            "subscriptionID" = "7c235ed2-aade-4f4c-a9d3-78f332fb5aee"
            "subscriptionName" = "UDAL Training"
            "location" = "uksouth"
            "orgCode" = "QBX"
            "coreRG" = "QBX-RG-CORE-PROD"
            "adRG" = "QBX-RG-AD-PROD"
            "tags" = $RGTags
        }
    }



    return $environments.$localenv
}