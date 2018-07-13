#!/bin/bash

# Requires root permissions


# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	usage:  [-h] [-t STRING]

	Setup crontab scheduling and edits transmission settings.

	optional arguments:
	    -t, --time          time to execute script eveyday e.g. 23:45
	other:
	    --help              print this help page 
	EOF
	exit 0
fi


# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in 
      -t|--time) TIME="$2"; shift ;;
      *) echo -e "Unknown argument:\t$arg"; exit 0 ;;
    esac

    shift
done

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# CRONTAB 
# crontab file alteration only if --time arg is parsed
if [ ! -z $TIME ]; then
	HOUR=$(echo $TIME | cut -d : -f 1)
	MINUTES=$(echo $TIME | cut -d : -f 2)
	CRONTAB_COMMAND="$MINUTES $HOUR * * * ${HOME}/.profile; .  ${HOME}/.bashrc; ${HERE}/autoTransmission.sh"
	(crontab -l ; echo "$CRONTAB_COMMAND") | uniq | crontab -
	crontab -l
fi


# AUTHENTICATION
# change the transmission settings to not require authorisation
sed -i 's/"rpc-authentication-required": true,/"rpc-authentication-required": false,/g' ${HOME}/.config/transmission-daemon/settings.json


# BASH ALIAS
echo alias autoTransmission="${HERE}/autoTransmission.sh" >> ${HOME}/.bashrc
