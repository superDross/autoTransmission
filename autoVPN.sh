#!/usr/bin/env bash
#
# autoVPN.sh; check VPN is connected every few minutes and reconnect if not.

# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoVPN.sh [-h] [-p DIR] [-i STR] [-s STR]

	Connects to VPN and re-establishes connection when lost.

	required arguments:
	  -p, --openvpn_dir   path to directroy containing .ovpn files
	optional arguments:
	  -s, --sleep         the amount of time to recheck VPN connection, default=20m
	  -i, --ip_site       website to scrape IP address from, default=http://ipecho.net/plain
	  -t, --setup         path to dir containing .ovpn files, enables a systemd service at boot
	options:
	  --remove_service    disables and removes created systemd service
	other:
	  --help              print this help page
	EOF
	exit 0
fi

# VARIABLES
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG="/tmp/$(basename "$0" .sh).log"

# LOGGING
log_date() { echo [`date '+%Y-%m-%d %H:%M:%S'`] ; }
info()	 { echo "[INFO] $(log_date): $*"  ; }
warning()  { echo "[WARNING] $(log_date): $*" ; }
error()	{ echo "[ERROR] $(log_date): $*"  ; }
fatal()	{ echo "[FATAL] $(log_date): $*" ; exit 1 ; }

# ARGUMENT PARSER
while [[ $# -gt 0 ]]; do
	arg="$1"
	case $arg in
	  -i|--ip_site) SITE="$2"; shift ;;
	  -p|--openvpn_dir) OPENVPN="$2"; shift ;;
	  -s|--sleep) SLEEP="$2"; shift ;;
	  -t|--setup) SETUP_OPENVPN="$2"; shift ;;
	  --remove_service) REMOVE=true; shift ;;
	  *) echo -e "Unknown argument:\t$arg"; exit 0 ;;
	esac
	shift
done

###############################################################################
# Ensures all mandatory arguments have been parsed and apply
# default values to optional arguemnts.
#
# Globals:
#	OPENVPN
#	SETUP_OPENVPN
#	SITE
#	SLEEP
# Arguemnts:
#	None
# Returns::
#	None
###############################################################################
arg_check() {
	if [[ -z $OPENVPN  && -z $SETUP_OPENVPN && -z $REMOVE ]]; then
		fatal "--openvpn_dir is compulsory"
	fi
	if [ -z $SITE ]; then
		info "setting default value for --ip_site=http://ipecho.net/plain"
		SITE="http://ipecho.net/plain"
	fi
	if [ -z $SLEEP ]; then
		info "setting default value for --sleep=20m"
		SLEEP="20m"
	fi
}

###############################################################################
# Exit if the script is not run as root user.
#
# Globals:
#	None
# Arguments:
#	command ($1): should be the script name and root restricted ARGS/options
# Returns:
# 	fatal msg
###############################################################################
sudo_check(){
	local command="$1"
	if [ "$(id -u)" != "0" ]; then
		fatal "$command most be run as root. Exiting."
	fi
}

###############################################################################
# Setup a systemd openvpn service to enable this script to work on boot.
#
# Globals:
#	HERE
#	SETUP_OPENVPN
#	SLEEP
# Arguments:
#	None
# Returns:
#	None
###############################################################################
setup() {
	sudo_check "autoVPN.sh --setup"
	cat <<-EOF > /lib/systemd/system/autoVPN.service
	[Unit]
	Description=autoVPN
	StartLimitIntervalSec=61
	StartLimitBurst=15

	[Service]
	Type=forking
	ExecStart=${HERE}/autoVPN.sh --openvpn_dir $SETUP_OPENVPN --sleep $SLEEP
	ExecStop=/usr/bin/killall openvpn
	Restart=always
	RestartSec=60
	Environment=DISPLAY=:%i
	TimeoutStartSec=0
	StandardOutput=syslog
	StandardError=syslog

	[Install]
	WantedBy=default.target
	EOF
	systemctl enable autoVPN.service
	systemctl start autoVPN.service
	info "autoVPN will work on boot now"
}

###############################################################################
# Remove and delete systemd service created using setup().
#
# Globals:
#	None
# Arguments:
#	None
# Returns:
#	None
###############################################################################
disable_service() {
	sudo_check "autoVPN.sh --remove_service"
	systemctl stop autoVPN
	systemctl disable autoVPN
	rm /lib/systemd/system/autoVPN.service
	systemctl daemon-reload
	systemctl reset-failed
}

###############################################################################
# Intiate VPN and kill all other openvpn processes.
#
# Globals:
#   OPENVPN
#   SITE
# Arguments:
#   None
# Returns:
#   None
###############################################################################
init_vpn() {
	pkill openvpn
	info "Initiating VPN"
	sudo openvpn ${OPENVPN}/*.ovpn &
	sleep 30
	info "Connected IP: $(curl $SITE)"
}

###############################################################################
# Initiate openvpn and monitor VPN connection over a given
# time period and reconnect to VPN when connection is lost.
#
# Globals:
#	OPENVPN
#	SITE
#	SLEEP
# Arguments:
#	None
# Returns:
#	None
###############################################################################
monitor_vpn() {
	if [ ! -z $OPENVPN ]; then
		# establish connection
		init_vpn
        local vpn_ip=$(curl $SITE)
		# monitor connection
        while [ "true" ]; do
			check_connection
			local current_ip=$(curl $SITE)
			if [[ $vpn_ip != $current_ip ]]; then
				init_vpn
			fi
			sleep $SLEEP
		done
	fi
}


###############################################################################
# Checks to see if openvpn has closed due to connection issues
# and ends service if that is the case.
#
###############################################################################
check_connection() {
	local error_msg="TLS key negotiation failed to occur within 60 seconds"
	local error=$(journalctl -u autoVPN.service | tail -n 50 | grep "$error_msg")
	if [ -z "$error" ]; then
		true
	else
		systemctl stop autoVPN.service
		exit 1
	fi
}

main() {
	# create log file if it does not exist
	if [ ! -f  $LOG ]; then
		touch $LOG
	fi
	arg_check
	# if --remove_service option parsed
	if [ ! -z $REMOVE ]; then
		disable_service
		exit 0
	fi
	# if --setup arg parsed
	if [ ! -z $SETUP_OPENVPN ]; then
		setup
		exit 0
	fi
	monitor_vpn
}

if [[ "$BASH_SOURCE" = "$0" ]];then
	main | tee -a "$LOG" >&2 
fi
