# The Active Directory Server

This will deploy an Active Directory server.  Under normal circumstances it would be recommended deploying Azure Active Directory Domain Services for the tenant in place of this, however for the purposes of this build it is assumed that a stand alone Active Directory virtual machine will be at the heart of this service.

This virtual machine will be pre-configured as much as possible as part of the Image Builder build, then commissioned using scripts to create a very basic AD server with computer object storage and a DNS server.