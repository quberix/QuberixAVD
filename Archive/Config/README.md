# Config

A multi-part deployment can be something of a challenge if you have to provide configuration data across multiple repositories.  It is therefore recommended that your entire azure deployment is from a single properly managed repository with the use of a central config that manages all parts of the deployment.

Another option might be to make use of the parameters settings and use central parameter arm templates to provide the same functionality.  This is probably closer to what you should do, but I personally find the use of a "config bicep file" much easier on the eye.

Of course this is a personal/organisational preference but it is the way I have deployed large scale services in the past and can centrally maintain settings, names, ip configuration, virtual networks etc.  The choice, as they say, is yours.