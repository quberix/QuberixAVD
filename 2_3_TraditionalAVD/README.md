# Traditional AVD deployment

This is considered the traditional AVD deployment which consists of a host pool (plus supporting components) and a number of pre-build virtual machine added to that pool and the Azure Scaling Plan to managing the turning on and off of those machines.

# Requirements

- A working Active Directory that supports domain objects, whether that is Azure Active Directory Domain Services (AADDS) or a virtual machine based Active Directory Domain Services (ADDS).  This is required as the virtual machines need to be domain joined.

- Connectivity between the AD and Azure Active Directory.  This is required for testing the AVD login.  It is possible to do it without that connectivity but you will lose a lot of the experience.  If you have AADDS, this is already implemented.  If you have a VM based AD (ADDS) then you will need to set up either AD Connect Cloud Sync or AD Connect (if you have not already done this).

- At least one non-admin account in AAD that will be used to log into the Host Pool (Added as an "Assignment" in the Application Group once created).  If using VM based ADDS, then this user should have ideally been created there and sync'ed up to AAD.

# Infrastructure Deployed


# Deployment


# Scaling




# Logging in

## With a Sync'ed AD account

## With just a local AD account
