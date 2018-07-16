#!/bin/bash
# autoTransmission.sh: Automate transmissin management and scheduling.
# NOTE: Add an option to implement the website django thing


# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoTransmission.sh [-h] [-t DIR] [-d DIR] [-s STRING] [-p STRING] [-o DIR ]

	Add torrents files to transmission and downoads data for a predetermined time period.

	required arguments:
	  -t, --torrent_dir      path to directory containing torrent/magnet files
	optional arguments:
	  -d, --download_dir     path to download data to, default=\$HOME/Downloads
	  -s, --sleep            the amount of time to download, default=6h
	  -c, --scheduler        time to initiate autoTransmission, permenantely adds to your crontab.
	  -a, --args             args/options to parse to transmission-remote
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
CMD="$@"
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG=${HERE}/log/autoTransmission.log


# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
	arg="$1"
	case $arg in 
	  -d|--download_dir) DOWNLOAD_DIR="$2"; shift ;;
	  -s|--sleep) SLEEP="$2"; shift ;;
	  -c|--scheduler) TIME="$2"; shift ;;
	  -t|--torrent_dir) TORRENT_DIR="$2"; shift ;;
	  -a|--args) ARGS="${@:2}"; shift ;;
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
		echo $(date): --args/-a must be the last argument given.
		exit 1
	fi
fi


# COMPULSORY ARGS
if [ -z $TORRENT_DIR ]; then
	echo "--torrent_dir is compulsory"
	exit 1
fi


# DEFAULT VALUES
if [ -z $SLEEP ]; then
	echo $(log_date): setting default value for --sleep=6h
	SLEEP="6h"
fi
if [ -z $DOWNLOAD_DIR ]; then
	echo $(log_date): setting default value for --download_dir=${HOME}/Downloads/
	DOWNLOAD_DIR=${HOME}/Downloads/
fi


scheduler() {
	# schedules time to execute autoTransmission everyday
	if [ ! -z $TIME ]; then
		HOUR=$(echo $TIME | cut -d : -f 1)
		MINUTES=$(echo $TIME | cut -d : -f 2)
		BASH_FILES="${HOME}/.profile; .  ${HOME}/.bashrc;" 
		# remove the --scheduler arg from the command
		COMMAND=$(echo "$CMD" |  sed 's/\(-c\|--scheduler\) [0-9]*:[0-9]*\ //g')
		# extract the autoTransmission commands and times currently within crontab file
		CURRENT_ENTRIES=$(crontab -l | grep auto)
		CURRENT_COMMAND=$(echo $CURRENT_ENTRIES | cut -d ' ' -f6-)
		CURRENT_COMMAND_TIME=$(echo $CURRENT_ENTRIES | cut -d ' ' -f-2)
		# exit if autoTransmisison aleady scheduled for the given time
		if [[ "$MINUTES $HOUR" = $CURRENT_COMMAND_TIME ]]; then
			echo $(log_date): autoTransmission is already scheduled for this time
			exit 1
		# only add transmission command if it isn't present within crontab already
		elif [[ $CURRENT_COMMAND != *"${HERE}/autoTransmission.sh ${COMMAND}"* ]]; then
			echo $(log_date): Updating crontab
			CRONTAB_COMMAND="$MINUTES $HOUR * * * $BASH_FILES ${HERE}/autoTransmission.sh $COMMAND"
			(crontab -l ; echo "$CRONTAB_COMMAND") | uniq | crontab -
		else
			echo $(log_date): command already written to crontab file
			exit 1
		fi
		exit 0
	fi
}


startup_app() {
	# construct log dir and file and start transmission
	echo $(log_date): ${HERE}/autoTransmission.sh $CMD
	mkdir -p ${HERE}/log
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
			echo "$(log_date): Adding $(basename $torrent_file)."
		elif [ ${torrent_file: -7} == ".magnet" ]; then
			transmission-remote -a `cat $torrent_file`
			echo "$(log_date): Adding $(basename $torrent_file)"
		else
			echo "$(log_date): Invalid file type: $(basename $torrent_file)"
		fi
		echo "$(log_date): Deleting $(basename $torrent_file)"
		rm $torrent_file
	done
}


parse_transmission_commands() {
	# parse --args arguments to transmission-remote
	if [[ ! -z $ARGS ]]; then
		echo $(log_date): parsing transmission remote commands
		transmission-remote $ARGS
	fi
}


download_time() {
	echo $(log_date): downloading for $SLEEP
	sleep $SLEEP
}	


remove_torrents() {
	# list all torrents, remove first & last line and first space on every line 
	# and use cut to get first field from each line
	TORRENTLIST=$(transmission-remote  -l | sed -e '1d;$d;s/^ *//' | \
			cut --only-delimited --delimiter \  --fields 1)
	# remove downloaded torrents and restart 'Stopped' torrents
	for torrent_id in $TORRENTLIST; do
		torrent_info=$(transmission-remote -t $torrent_id --info)
		downloaded=$(echo $torrent_info | grep "Percent Done: 100%")
		stopped=$(echo $torrent_info | grep "State: Stopped")
		torrent_name=$(echo $torrent_info | grep Name | cut -d : -f 2)
		if [ "$downloaded" != "" ]; then
			transmission-remote  -t $torrent_id --remove
			echo "$(log_date): $torrent_name successfully downloaded "
			echo "$(log_date): Removing $torrent_name from torrent list"
		elif [ "$stopped" != "" ]; then
			transmission-remote -t $torrent_id -s
			echo $(log_date): Restarting $torrent_name
		fi
	done
}


exit_transmission() {
	echo $(date): exiting transmission.
	transmission-remote --exit
}


autoTransmission() {
	scheduler
	startup_app
	init_VPN
	add_torrents
	parse_transmission_commands
	download_time
	remove_torrents
	exit_transmission
	kill_vpn
	echo "$(log_date): autoTransmission Complete!"
}


autoTransmission | tee $LOG
