#!/bin/bash
# Requires root permissions


# CRONTAB
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CRONTAB_COMMAND="45 23 * * . ${HOME}/.profile; .  ${HOME}/.bashrc; ${HERE}/execute.sh"

(crontab -l ; echo $COMMAND) | uniq | crontab -


# change the transmission settings to not require authorisation
sed -i 's/"rpc-authentication-required": true,/"rpc-authentication-required": false,/g' /etc/transmission-daemon/settings.json
