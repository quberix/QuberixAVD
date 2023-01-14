<#
.SYNOPSIS
    This script will upgrade all hosts in a hostpool to the latest version of the image

.DESCRIPTION
    1. Turn any scaler off
    2. Build a list of all hosts in the host pool
    3. Set all hosts to drain mode (that are turned on) and notify any connected users to log off (10 min warning)
    4. Change the hostpool key to a new key
    5. Build a new host and add it to the hostpool using the latest image then shut it down
    6. Remove an old host (starting with the ones that are off, then the ones with zero users, then wait until all users have logged off or 10 min warning expired)
    7. Cycle 5 and 6 until all hosts have been upgraded
    8. Start up the number og hosts required to equal that when the job started
    9. Turn the scaler back on (if required)
#>
