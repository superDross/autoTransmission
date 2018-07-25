#!/usr/bin/env bash
# autoTransmission.sh: Automate transmission management and scheduling.
# NOTE: Add an option to implement the website django thing

set -eo pipefail

# HELP PAGE
# NOTE: --ratio, --download_dir --torrent_dir are actually not needed as they are already available as
#       --global-seedratio, --download-dir and -c respectively in transmission-daemon.
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoTransmission.sh [-h] [-t DIR] [-d DIR] [-s STRING] [-p STRING] [-o DIR ] [-r FLOAT]

	Add torrents files to transmission and downoads data for a predetermined time period.

	required arguments:
	  -t, --torrent_dir      path to directory containing torrent/magnet files
	optional arguments:
	  -d, --download_dir     path to download data to, default=\$HOME/Downloads
	  -s, --sleep            the amount of time to download, default=6h
	  -c, --scheduler        time to initiate autoTransmission, permenantely adds to your crontab
	  -r, --ratio            download/upload ratio threshold to reach before removing torrent
	  -a, --args             args/options to parse to transmission-remote
	other:
	  --help                 print this help page 
	EOF
	exit 0
fi


# LOGGING
LOG="/tmp/$(basename  "$0" .sh).log"
log_date() { echo [`date '+%Y-%m-%d %H:%M:%S'`] ; }
info()     { echo "[INFO] $(log_date): $*" | tee -a "$LOG" >&2 ; }
warning()  { echo "[WARNING] $(log_date): $*" | tee -a "$LOG" >&2 ; }
error()    { echo "[ERROR] $(log_date): $*" | tee -a "$LOG" >&2 ; }
fatal()    { echo "[FATAL] $(log_date): $*" | tee -a "$LOG" >&2 ; exit 1 ; }


# VARIABLES
CMD="$@"
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
	arg="$1"
	case $arg in 
	  -d|--download_dir) DOWNLOAD_DIR="$2"; shift ;;
	  -s|--sleep) SLEEP="$2"; shift ;;
	  -c|--scheduler) TIME="$2"; shift ;;
	  -t|--torrent_dir) TORRENT_DIR="$2"; shift ;;
	  -r|--ratio) RATIO="$2"; shift ;;
	  -a|--args) ARGS="${@:2}"; shift ;;
	  --setup) SETTINGS="/var/lib/transmission-daemon/.config/transmission-daemon/settings.json" ;;
	  #*) echo -e "Unknown argument:\t$arg"; exit 0 ;;
	esac
	shift
done


# ERROR CHECKING
# exit if --arg|-a is parsed but is not the last argument given
if [[ $CMD = *"--args"* || $CMD = *"-a"* ]]; then
	ALL_ARGS="\-d\|-s\|-c\|-t\|-p\|-o\|-a\|--args\|--vpn_dir\|--ip_site\|--torrent_dir\|--scheduler\|--sleep\|--download_dir"
	ARGUMENTS=$(echo $CMD | grep $ALL_ARGS -o)
	LAST_ARG=$(echo $ARGUMENTS | awk '{print $NF}')
	if [[ $LAST_ARG != "--args" && $LAST_ARG != "-a" ]]; then
		fatal "--args/-a must be the last argument given."
	fi
fi


# COMPULSORY ARGS
if [[ -z $TORRENT_DIR && -z $SETTINGS && -z $TIME ]]; then
	fatal "--torrent_dir is compulsory"
fi


# DEFAULT VALUES
if [[ -z $SLEEP && -z $SETTINGS && -z $TIME ]]; then
	info "setting default value for --sleep=6h"
	SLEEP="6h"
fi
if [[ -z $DOWNLOAD_DIR && -z $SETTINGS && -z $TIME ]]; then
	info "setting default value for --download_dir=${HOME}/Downloads/"
	DOWNLOAD_DIR=${HOME}/Downloads/
fi


sudo_check(){
	# exit script if the script is not run as root user
	# $1 should be the script name and root restricted args/options
	if [ "$(id -u)" != "0" ]; then
		fatal "$1 most be run as root. Exiting."
	fi
}


setup() {
	# exit if not run by root user
	sudo_check "autoTransmission.sh --settings"
	service transmission-daemon stop
	# transmission authentication disabling
	if grep '"rpc-authentication-required": true' $SETTINGS; then
		info "changing transmission authentication settings."
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
	# restart service
	service transmission-daemon start
}


scheduler() {
	# allows parsing of schedule
	if [[ -z $TIME ]]; then
		TIME=$1
	fi
	# schedules time to execute autoTransmission everyday
	# remove the --scheduler arg from the command
	HOUR=$(echo $TIME | cut -d : -f 1)
	MINUTES=$(echo $TIME | cut -d : -f 2)
	BASH_FILES="${HOME}/.profile; .  ${HOME}/.bashrc;" 
	CRONTAB_COMMAND="$MINUTES $HOUR * * * $BASH_FILES ${HERE}/autoTransmission.sh $COMMAND"
	COMMAND=$(echo "$CMD" |  sed 's/\(-c\|--scheduler\) [0-9]*:[0-9]*\ //g')
	# only add transmission command if it isn't present within crontab already
	if [ ! -z "$(crontab -l | grep autoTransmission)" ]; then
		# extract the autoTransmission commands and times currently within crontab file
		fatal "autoTransmission already present within the crontab file"
	else
		info "Updating crontab"
		(crontab -l ; echo "$CRONTAB_COMMAND") | uniq | crontab -
	fi
}


startup_app() {
	# construct log dir and file and start transmission
	info "${HERE}/autoTransmission.sh $CMD"
	touch $LOG
	transmission-daemon -w $DOWNLOAD_DIR
	sleep 5
}


delete_old() { 
	# delete files from directory containing torrent/magnets that are older than 72 hours
	find $TORRENT_DIR -type f -mmin +4320 -exec rm {} \;
}


add_torrents() {
	# add all torrents & magnets in a given dir to transmission, then delete said file 
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


parse_transmission_commands() {
	# parse --args arguments to transmission-remote
	info "parsing transmission remote commands"
	transmission-remote $ARGS
}


download_time() {
	info "downloading for $SLEEP"
	sleep $SLEEP
}	


remove_torrents() {
	torrent_id_list=$(transmission-remote  -l | sed -e '1d;$d;s/^ *//' | \
			cut --only-delimited --delimiter \  --fields 1)
	# remove downloaded torrents and restart 'Stopped' torrents
	for torrent_id in $torrent_id_list; do
		torrent_info=$(transmission-remote -t $torrent_id --info)
		downloaded=$(echo $torrent_info | grep "Percent Done: 100%")
		stopped=$(echo $torrent_info | grep "State: Stopped")
		torrent_name=$(echo $torrent_info | grep Name | cut -d : -f 2)
		ratio=$(echo $torrent_info | grep -o "Ratio: [0-9]*.[0-9]" | cut -d ' ' -f2)
		ratio_met=$(echo "$ratio >= $RATIO" | bc -l)
		# remove torrent only if --ratio given and torrent meets the value parsed
		if [[ ! -z $RATIO && $ratio_met = 1 ]]; then
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


exit_transmission() {
	info "exiting transmission."
	transmission-remote --exit
	# kill all transmission daemon processes
	local pids=$(ps aux | grep -v grep | grep transmission-daemon | awk '{print $2}')
	for pid in $pids; do
		kill -9 $pid
	done
}


autoTransmission() {
	if [ ! -z $SETTINGS ]; then
		setup
		exit 0
	fi
	if [ ! -z $TIME ]; then
		scheduler
		exit 0
	fi
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
	autoTransmission | tee $LOG
fi
