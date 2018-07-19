#!/bin/bash
# autoVPN.sh; check VPN is connected every few minutes and reconnect if not.

set -euo pipefail

# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoVPN.sh [-h] [-p DIR] [-i STR] [-s STR]

	Connects to VPN and re-establishes connection when lost.

	required arguments:
	  -p, --openvpn_dir      path to directroy containing .ovpn files
	optional arguments:
	  -s, --sleep            the amount of time to recheck VPN connection, default=5m
	  -i, --ip_site          website to scrape IP address from, default=http://ipecho.net/plain
	  --setup                path to dir containing .ovpn files, enables a systemd service at boot
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
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG=${HERE}/log/autoVPN.log


# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
	arg="$1"
	case $arg in 
	  -i|--ip_site) SITE="$2"; shift ;;
	  -p|--openvpn_dir) OPENVPN="$2"; shift ;;
	  -s|--sleep) SLEEP="$2"; shift ;;
	  --setup) OPENVPN_DIR="$2"; shift ;;
	  *) echo -e "Unknown argument:\t$arg"; exit 0 ;;
	esac
	shift
done


# COMPULSORY ARGS
if [[ -z $OPENVPN  && -z $OPENVPN_DIR ]]; then
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


sudo_check(){
	# exit script if the script is not run as root user
	# $1 should be the script name and root restricted args/options
	if [ "$(id -u)" != "0" ]; then
		echo "$(date): $1 most be run as root. Exiting."
		exit 1
	fi
}


setup() {
	# setup a systemd openvpn service to enable this script to work on boot
	sudo_check "autoVPN.sh --setup"
	if [ ! -z $OPENVPN_DIR ]; then
		echo "Do you want to set up autoVPN as a systemd service (press anykey)?"
		read answer
		# create systemd file
		cat <<-EOF > /lib/systemd/system/autoVPN.service
		[Unit]
		Description=autoVPN
		StartLimitIntervalSec=61
		StartLimitBurst=15
		Startlimitaction=none

		[Service]
		Type=forking
		ExecStart=${HERE}/autoVPN.sh --openvpn_dir $OPENVPN_DIR
		ExecStop=/usr/bin/killall openvpn
		Restart=always
		RestartSec=60
		Environment=DISPLAY=:%i
		TimeoutStartSec=0

		[Install]
		WantedBy=default.target
		EOF
		# enable systemd service
		systemctl enable autoVPN.service
		echo $(log_date): autoVPN will work on boot now
		exit 1
	fi
}


init_VPN() {
	# initiate openvpn and monitor/re-establish VPN connection
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


autoVPN() {
	setup
	init_VPN 
}


autoVPN | tee $LOG
