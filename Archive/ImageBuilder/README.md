# Build Setup

There are two files that will be deployed as part of any build and from these files, all software will be installed.

## The package file

The package file is a JSON file that defines a list of software that will be installed on one or more images.  In this example it is simply called **packages.json**.  It has the format:

```json
{
    "Package Group": {
        "Package Name": {
            "Install Type": "string",
            "Location or name of package to install": "string",
            "Parameters": "string",
            "Custom": "string"
        }
    }
}
```

**Package Group** - this defines a group to which this package belongs.  These groups are then assigned to the desktop.  For example you might have a Common group with all software in that group being installed on all desktops.  Please see the Desktop File for how this is applied.

**Package Name** - A plain english name for the package

**Installation Type** - this can be any of the following:

- Role - installs a windows role
- Feature - installs a windows feature
- Choco - installs a package from Chocolatey
- Winget - Installs a package using WinGet
- Repo - Installs a file from a Azure storage account repository
- Python - Installs a python module or list of modules
- Custom - Takes a path to a powershell script and uses that to install a package

**Location** - This provides the location of the installer or the name of the package to install

- Role - the name of the role
- Feature - the name of the feature
- Choco - the name of the chocolatey package
- Winget - the name of the package provided through winget
- Repo - The full path to a storage account file resource e.g. exe, msi
- Python - the name of a python module, or if a path to a storage account file resource, will install a list of packages
- Custom - full path to the storage account file resource for a powershell script to run.

**Parameters** - any command line or package parameters required to install the file/package/role/feature/script

**Custom** - any custom elements required for the package installation
## The desktops file

The Desktops file is another JSON file that defines which packages belong to which desktop.  In this example it is called **desktops.json**.  It has the format:

```json
{
    "Desktop Name 1": ["Package Group 1","Package Group 2"],
    "Desktop Name 2": ["Package Group 1","Package Group 3", "Package Group 4"]
}
```

**Desktop Name** - this is the name of the desktop as also defined in the central config file.  It is important that the two match

The content of the Desktop Name is an array listing the package groups to install for that desktop.  This links the Desktop to the packages.json, so again it is important that the "Package Group" matches the same name as defined in the packages.json file.