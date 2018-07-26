#!/usr/bin/env bash
#
# autoTransmission.sh: Automate transmission management and scheduling.
#
# NOTE: --ratio, --download_dir --torrent_dir are actually not needed as they are already available as
#       --global-seedratio, --download-dir and -c respectively in transmission-daemon.

set -eo pipefail

# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoTransmission.sh [-h] [-t DIR] [-d DIR] [-s STRING] [-p STRING] [-o DIR ] [-r FLOAT]

	Add torrents files to transmission and downoads data for a predetermined time period.

	required arguments:
	  -t, --torrent_dir      path to directory containing torrent/magnet files
	optional arguments:
	  -d, --download_dir     path to download data to, default=\$HOME/Downloads
	  -s, --sleep            the amount of TIME to download, default=6h
	  -c, --scheduler        time to initiate autoTransmission, permenantely adds to your crontab
	  -r, --ratio            download/upload ratio threshold to reach before removing torrent
	  -a, --args             args/options to parse to transmission-remote
	options
	  --setup                alter transmission-daemon settings and bashrc files
	other:
	  --help                 print this help page 
	EOF
	exit 0
fi

# VARIABLES
CMD="$@"
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG="/tmp/$(basename  "$0" .sh).log"

# LOGGING
log_date() { echo [`date '+%Y-%m-%d %H:%M:%S'`] ; }
info()     { echo "[INFO] $(log_date): $*" | tee -a "$LOG" >&2 ; }
warning()  { echo "[WARNING] $(log_date): $*" | tee -a "$LOG" >&2 ; }
error()    { echo "[ERROR] $(log_date): $*" | tee -a "$LOG" >&2 ; }
fatal()    { echo "[FATAL] $(log_date): $*" | tee -a "$LOG" >&2 ; exit 1 ; }

# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
	arg="$1"
	case $arg in 
	  -d|--download_dir) DOWNLOAD_DIR="$2"; shift ;;
	  -s|--sleep) SLEEP="$2"; shift ;;
	  -c|--scheduler) TIME="$2"; shift ;;
	  -t|--torrent_dir) TORRENT_DIR="$2"; shift ;;
	  -r|--ratio) RATION_LIMIT="$2"; shift ;;
	  -a|--args) ARGS="${@:2}"; shift ;;
	  --setup) SETTINGS="/var/lib/transmission-daemon/.config/transmission-daemon/settings.json" ;;
	  #*) echo -e "Unknown argument:\t$arg"; exit 0 ;;
	esac
	shift
done


###############################################################################
# Ensures all mandatory arguments have been parsed and are
# in the desired order
#
# Globals:
#	TORRENT_DIR
#	SETTINGS
#	TIME
#	CMD
# Arguemnts:
#	None
# Returns::
#	None
###############################################################################
arg_check() {
	if [[ -z $TORRENT_DIR && -z $SETTINGS && -z $TIME ]]; then
		fatal "--torrent_dir is compulsory"
	fi
	if [[ $CMD = *"--args"* || $CMD = *"-a"* ]]; then
		local all_args="\-d\|-s\|-c\|-t\|-p\|-o\|-a\|--args\|--vpn_dir\|--ip_site\|--torrent_dir\|--scheduler\|--sleep\|--download_dir"
		local arguments=$(echo $CMD | grep $all_args -o)
		local last_arg=$(echo $arguments | awk '{print $NF}')
		if [[ $last_arg != "--args" && $last_arg != "-a" ]]; then
			fatal "--args/-a must be the last argument given."
		fi
	fi
}


###############################################################################
# Apply default values to optional argsuments.
#
# Globals:
#	SLEEP
#	DOWNLOAD_DIR
# Arguemnts:
#	None
# Returns:
#	Default variables
###############################################################################
apply_defaults() {
	if [[ -z $SLEEP && -z $SETTINGS && -z $TIME ]]; then
		info "setting default value for --sleep=6h"
		SLEEP="6h"
	fi
	if [[ -z $DOWNLOAD_DIR && -z $SETTINGS && -z $TIME ]]; then
		info "setting default value for --download_dir=${HOME}/Downloads/"
		DOWNLOAD_DIR=${HOME}/Downloads/
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
# Alters transmission-daemon settings to not require authentication for use
# and adds an alias to users bashrc.
# 
# Globals:
#	None
# Arguments
#	None
# Returns:
#	None
###############################################################################
setup() {
	sudo_check "autoTransmission.sh --SETTINGS"
	service transmission-daemon stop
	# transmission authentication disabling
	if grep '"rpc-authentication-required": true' $SETTINGS; then
		info "changing transmission authentication SETTINGS."
		sed -i 's/"rpc-authentication-required": true,/"rpc-authentication-required": false,/g' $SETTINGS
	else
		info "Authentication already disabled."
	fi
	# bash alias added to .bashrc
	if grep --quiet "alias autoTransmission=" ${HOME}/.bashrc; then
		info "autoTransmission alias already present in the users BASHRC"
	else
		info "appending autoTransmission to bashrc"
		echo alias autoTransmission="${HERE}/autoTransmission.sh" >> ${HOME}/.bashrc
	fi
	service transmission-daemon start
}

###############################################################################
# Adds the autoTransmission command parsed from the commandline 
# to cron to be scheduled for a given time everyday.
#
# Globals:
#	HOME
#	HERE
#	CMD
# Arguments
#	time ($1): a time in 24h format e.g. 23:45
# Returns:
#	None
###############################################################################
scheduler() {
	local time=$1
	local hour=$(echo $time | cut -d : -f 1)
	local minutes=$(echo $time | cut -d : -f 2)
	local bash_files="${HOME}/.profile; .  ${HOME}/.bashrc;" 
	# remove the --scheduler arg from the command
	local args=$(echo "$CMD" |  sed 's/\(-c\|--scheduler\) [0-9]*:[0-9]*\ //g')
	local crontab_command="$minutes $hour * * * $bash_files ${HERE}/autoTransmission.sh $args"
	# only add transmission command if it isn't present within crontab already
	if [ ! -z "$(crontab -l | grep autoTransmission)" ]; then
		fatal "autoTransmission already present within the crontab file"
	else
		info "Updating crontab"
		(crontab -l ; echo "$crontab_command") | uniq | crontab -
	fi
}


###############################################################################
# Start transmision-daemon and create log file.
#
# Globals:
#	LOG
#	HERE
#	CMD
#	DOWNLOAD_DIR
# Arguments
#	None
# Returns:
#	None
###############################################################################
startup_app() {
	if [ ! -f $LOG ]; then
		touch $LOG
	fi
	info "${HERE}/autoTransmission.sh $CMD"
	transmission-daemon -w $DOWNLOAD_DIR
	sleep 5
}

###############################################################################
# Delete files from directory containing torrent/magnets that
# are older than 72 hours.
#
# Globals:
#	TORRENT_DIR
# Arguments
#	None
# Returns:
#	None
###############################################################################
delete_old() { 
	find $TORRENT_DIR -type f -mmin +4320 -exec rm {} \;
}

###############################################################################
# Add all torrents & magnets in a given dir to transmission,
# then delete said file.
#
# Globals:
#	TORRENT_DIR
# Arguments
#	None
# Returns:
#	None
###############################################################################
add_torrents() {
	for torrent_file in ${TORRENT_DIR}/*; do
		if [ ${torrent_file: -8} == ".torrent" ]; then
			transmission-remote  -a $torrent_file
			info "Adding $(basename $torrent_file)."
		elif [ ${torrent_file: -7} == ".magnet" ]; then
			transmission-remote -a `cat $torrent_file`
			info "Adding $(basename $torrent_file)"
		else
			error "Invalid file type: $(basename $torrent_file)"
		fi
		info "Deleting $(basename $torrent_file)"
		rm $torrent_file
	done
}

###############################################################################
# Parse given --args arguments to transmission-remote.
#
# Globals:
#	None
# Arguemnts:
#	None
# Returns:
#	None
###############################################################################
parse_transmission_commands() {
	info "parsing transmission remote commands"
	transmission-remote $ARGS
}

###############################################################################
# Sleep and download for a predetermined amount of time.
#
# Globals:
#	SLEEP
# Arguments
#	None
# Returns:
#	None
###############################################################################
download_time() {
	info "downloading for $SLEEP"
	sleep $SLEEP
}	

###############################################################################
# Remove completed torrents and restart 'Stopped' torrents.
#
# Globals:
#	RATIO_LIMIT
# Arguments
# 	None
# Returns:
#	None
###############################################################################
remove_torrents() {
	local torrent_id_list=$(transmission-remote  -l | sed -e '1d;$d;s/^ *//' | \
			cut --only-delimited --delimiter \  --fields 1)
	for torrent_id in $torrent_id_list; do
		local torrent_info=$(transmission-remote -t $torrent_id --info)
		local downloaded=$(echo $torrent_info | grep "Percent Done: 100%")
		local stopped=$(echo $torrent_info | grep "State: Stopped")
		local torrent_name=$(echo $torrent_info | grep Name | cut -d : -f 2)
		local ratio=$(echo $torrent_info | grep -o "Ratio: [0-9]*.[0-9]" | cut -d ' ' -f2)
		local ratio_met=$(echo "$ratio >= $RATION_LIMIT" | bc -l)
		# remove torrent only if --ratio given and torrent meets the value parsed
		if [[ ! -z $RATION_LIMIT && $ratio_met = 1 ]]; then
			transmission-remote  -t $torrent_id --remove
			info "$torrent_name successfully downloaded "
			info "Removing $torrent_name from torrent list"
		# remove torrent only if downloaded = 100%
		elif [ "$downloaded" != "" ]; then
			transmission-remote  -t $torrent_id --remove
			info "$torrent_name successfully downloaded "
			info "Removing $torrent_name from torrent list"
		# restart torrent if stopped
		elif [ "$stopped" != "" ]; then
			transmission-remote -t $torrent_id -s
			info "Restarting $torrent_name"
		fi
	done
}

###############################################################################
# Exit transmission and kill all transmission-daemon processes.
#
# Globals:
#	None
# Arguments
#	None
# Returns:
#	None
###############################################################################
exit_transmission() {
	info "exiting transmission."
	transmission-remote --exit
	local pids=$(ps aux | grep -v grep | grep transmission-daemon | awk '{print $2}')
	for pid in $pids; do
		kill -9 $pid
	done
}

main() {
	if [ ! -z $SETTINGS ]; then
		setup
		exit 0
	fi
	if [ ! -z $TIME ]; then
		scheduler $TIME
		exit 0
	fi
	apply_defaults
	arg_check
	startup_app
	add_torrents
	if [[ ! -z $ARGS ]]; then
		parse_transmission_commands
	fi
	download_time
	remove_torrents
	exit_transmission
	info "autoTransmission Complete!"
}

if [[ "$BASH_SOURCE" = "$0" ]];then 
	main | tee $LOG
fi
