#!/bin/bash
# setup.sh; 


# VARIABLES
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# SUDO CHECK
if [ "$(id -u)" != "0" ]; then
	echo "$(date): This script must be run as root"
	exit 1
fi

# AUTHENTICATION
# change the transmission settings to not require authorisation
service transmission-daemon stop
SETTINGS="/var/lib/transmission-daemon/.config/transmission-daemon/settings.json"
sed -i 's/"rpc-authentication-required": true,/"rpc-authentication-required": false,/g' $SETTINGS


# BASH ALIAS
if grep "alias autoTransmission=" ${HOME}/.bashrc; then
	echo autoTransmission alias already present in the users BASHRC
else
	echo alias autoTransmission="${HERE}/autoTransmission.sh" >> ${HOME}/.bashrc
fi
