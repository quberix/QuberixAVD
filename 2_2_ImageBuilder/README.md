# Notes

Traditionally, you would deploy this to DEV only then create a pipeline to COPY the image from DEV compute gallery to the PROD compute gallery.  However, there is now an optional step as different subscriptions can now use a single gallery.  Both have merits, a single gallery's images can be tagged with DEV then promoted to PROD once tested and is cheaper to run, but this requires more logic.  Dual gallerys keep dev and prod fully separate with a formal gateway and approval process to transfer it to prod. This is more expensive to run, but is more secure.

# Single Compute Gallery

This provides a single environment image builder and compute gallery.  This can then be used as part of a single compute gallery deployment.

# Multi Compute Gallery

This builds both a DEV AND PROD (though you could also have other in-between stages as well) environment where the DEV environment provides an image builder infrastrcture and dev compute gallery and the production environment provides just a compute gallery.  Provided is two ways to copy the image from the dev to the production compute gallery - a simple powershell script that jsut copies the latest image over, and a more comprehensve YAML pipeline that monitors runs continuous development of the dev environment (monitoring changes to the build) AND an approval process that then copies the file from DEV to PROD.

# The Builder environment (relevant to both environments)

This provides the image builder infrastructure including a dedicated storage account that provides a "repo" of software that the images can call on as part of the build.  The builder also leverages examples of both "chocolatey" and "winbuild" to show how both of these could be used as well.

# Requirements for Software deployment to an Image

Each desktop deployment has a set of requirements associated with it:

1. The deploy.bicep - defines the parameters for the desktop and what to actually build
1. The InstallSoftware.ps1 - a script that uses the common InstallSoftwareLibrary module to actually manipulate the image and install software
1. The ValidateEnvironment.ps1 - a script that is used as part of the build to validate the environment.

## The deploy.bicep

The deploy.bicep provides a number of customisation sections and needs to be customised to suit your needs.  The two main areas for customisation are:

- sourceImage
    - The source image defines which base image to use as part of the build.  Typically this is a Windows 10 or 11 AVD specific MultiSession image is using this process for AVD, but can also be your own custom image or a standalone image as well
- customizationSteps
    - This is where the Image Builder does the work of customising the image by calling several Packer Features.  A typical build would be:
        1. Download the build scripts
        1. Run the InstallSoftware.ps1 script
        1. Run the ValidateEnvironment.ps1 script
        1. Reboot the VM
        1. Do windows updates
        1. Reboot the VM
        1. Generalise the image

    - This can, of course, be anything you want in the image build and in any order.  For example, if you need a reboot between installations of different packages, you would create two InstallSoftware.ps1 scripts, then add a reboot and another Powershell section to the customizationSteps.

## The InstallSoftware.ps1 script

This script does the customisation of the image.  Everything defined in here is designed to install software or manipulate the image to make it the image you require.  It relies heavily on the InstallSoftwareLibrary.psm1 powershell module to automate and simplify the installation of software and customisation of the image, however it is not an absolute requirement - you can add whatever you want to this powershell script to customise the image though powershell in any way.

Just remember though that:
1. This script will run as a local admin during the build, so user installed software CANNOT be installed this way.  An example of this is VS Code Extensions.
1. The VM you are running the build is not and MUST NOT be joined to the domain otherwise it will not generalise properly.
1. The installation script is designed to operate from a single Azure storage account Blob container - If you need to use multiple containers, then you will need to build and launch a separate installer script for each one.

## The ValidateEnvironment.ps1 script

This script is really up to you.  Some basic checks have been added by way of example, but this script is to help you automate the checking and validation of the image you have just built e.g. to ensure all the software has installed correctly.


# Building an image

## Prep the image folder

In order to build the image you will need to:
1. Create a new folder (suggest the name of the image)
1. Copy in (or create new) the deploy.bicep - modify this as required
1. Create a sub-folder called "BuildScripts"
1. Copy into this (or create new), the InstallSoftware.ps1 and ValidateEnvironment.ps1 scripts

## Validate the build script

In this deployment, there are two build scripts:

1. 1_deployCommon.ps1
    - This provides the gallery, storage account and uploads the contents of the "Components/TEstSoftware" folder to a "repository" container

1. 2a_deploySingleEnv.ps1 **OR** 2b_deployMultiEnv.ps1
    - Check then run either of these two scripts to configure the UMI and permissions, upload the build scripts and create the image

You will need to make sure that PSConfig/deployConfig.psm1 is correct which, if you have been following the series, should have been done earlier.

## Run the build script
