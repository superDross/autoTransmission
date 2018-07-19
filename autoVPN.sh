#!/bin/bash

# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoVPN.sh [-h] [-p DIR] [-i STR] [-s STR]

	Connects to VPN and re-establishes connection when lost.

	required arguments:
	  -t, --torrent_dir      path to directory containing torrent/magnet files
	optional arguments:
	  -p, --openvpn_dir      path to download data to dir containing .ovpn files
	  -s, --sleep            the amount of time to recheck VPN connection, default=5m
	  -i, --ip_site          website to scrape IP address from, default=http://ipecho.net/plain
	other:
	  --help                 print this help page 
	EOF
	exit 0
fi


# UNIVERSAL FUNCTION
log_date() {
	echo [`date '+%Y-%m-%d %H:%M:%S'`] 
}


# VARIABLES
LOG=${HERE}/log/autoVPN.log


# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
	arg="$1"
	case $arg in 
	  -i|--ip_site) SITE="$2"; shift ;;
	  -p|--openvpn_dir) OPENVPN="$2"; shift ;;
	  -s|--sleep) SLEEP="$2"; shift ;;
	  *) echo -e "Unknown argument:\t$arg"; exit 0 ;;
	esac
	shift
done


# COMPULSORY ARGS
if [ -z $OPENVPN ]; then
	echo "$(log_date): --openvpn_dir is compulsory"
	exit 1
fi


# DEFAULT VALUES
if [ -z $SITE ]; then
	SITE="http://ipecho.net/plain"
fi
if [ -z $SLEEP ]; then
	SLEEP="5m"
fi


init_VPN() {
	if [ ! -z $OPENVPN ]; then
		pkill openvpn
		HOME_IP=$(curl $SITE)
		echo "$(log_date): Home IP: $HOME_IP"
		# if the IP address is the same as HOME_IP then connect to VPN.
		# check every 30 minutes
		while [ "true" ]; do
		CURRENT_IP=$(curl $SITE)	
		if [ $HOME_IP = $CURRENT_IP ]; then
			echo "$(log_date): Initiating VPN"
			sudo openvpn ${OPENVPN}/*.ovpn &
			echo "$(log_date): Connected IP: $(curl $SITE)"
		fi
		sleep $SLEEP
		done
	fi
}


kill_vpn() {
	if [ ! -z $OPENVPN ]; then
		pkill openvpn
	fi
}


init_VPN | tee $LOG
