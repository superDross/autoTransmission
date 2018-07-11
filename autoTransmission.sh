#!/bin/bash


# HELP PAGE
if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
	cat <<- EOF
	Usage:  autoTransmission.sh [-h] [-t DIR] [-d DIR] [-s STRING] [-p STRING] [-o DIR ]

	Add torrents files to transmission and downoads data for a predetermined time period.

	required arguments:
	    -t, --torrent_dir          path to directory containing torrent/magnet files
	optional arguments:
	    -d, --download_dir         path to download data to, default=\$HOME/Downloads
	    -s, --sleep                the amount of time to download, default=6h
	    -p, --ip_site              website to scrape IP address from, --ip_site=http://ipecho.net/plain
	    -o, --vpn_dir              directory containing ovpn and certificate files for VPN initiation
	other:
	    --help                     print this help page 
	EOF
	exit 0
fi


# UNIVERSAL FUNCTION
log_date() {
	echo [`date '+%Y-%m-%d %H:%M:%S'`] 
}


# VARIABLES
CMD=$(echo autoTransmission.sh $@)
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG=${HERE}/log/autoTransmission.log


# ARGUMENT PARSER 
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in 
	  -d|--download_dir) DOWNLOAD_DIR="$2"; shift ;;
      -s|--sleep) SLEEP="$2"; shift ;;
	  -t|--torrent_dir) TORRENT_DIR="$2"; shift ;;
	  -p|--ip_site) SITE="$2"; shift ;;
	  -o|--vpn_dir) OPENVPN="$2"; shift ;;
      *) echo -e "Unknown argument:\t$arg"; exit 0 ;;
    esac

    shift
done


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
if [ -z $SITE ]; then
	echo $(log_date): setting default value for --ip_site=http://ipecho.net/plain
	SITE="http://ipecho.net/plain"
fi
if [ -z $DOWNLOAD_DIR ]; then
	echo $(log_date): setting default value for --download_dir=${HOME}/Downloads/
	DOWNLOAD_DIR=${HOME}/Downloads/
fi


# FUNCTIONS

delete_old() { 
    # delete files from directory containing torrent/magnets that are older than 72 hours
    find $TORRENT_DIR -type f -mmin +4320 -exec rm {} \;
}


init_VPN() {
	# NOTE: requires sudo.
	pkill openvpn
	
	HOME_IP=$(curl $SITE)
	echo "$(log_date): Home IP: $HOME_IP"
	
	while [ "true" ]; do
	CURRENT_IP=$(curl $SITE)	
	if [ $HOME_IP = $CURRENT_IP ]; then
	echo "$(log_date): Initiating VPN"
	sudo openvpn ${OPENVPN}/*.ovpn &
	echo "$(log_date): Connected IP: $(curl $SITE)"
	fi
	sleep 30
	done
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
            echo "$torrent_name successfully downloaded "
			echo -e "$(log_date): Removing $torrent_name from torrent list... \n"

        elif [ "$stopped" != "" ]; then
	        transmission-remote -t $torrent_id -s
			echo -e "$(log_date): Restarting $torrent_name ...... \n"
        fi

    done
}


autoTransmission() {
	echo $CMD
	# construct log dir and file
	mkdir -p ${HERE}/log
	touch $LOG
	# inititiate VPN if --vpn_dir arg given
	if [ ! -z $OPENVPN ]; then
		init_VPN
	fi
	# delete torrent/magnet files
	delete_old
    # start daemon and specify a dir to download data to 
    transmission-daemon -w $DOWNLOAD_DIR
	sleep 10
	# add all torrent/magnet files to transmission
	add_torrents
	sleep $SLEEP
	# remove completly downloaded torrents and restart stopped torrents
	remove_torrents
	# exit transmission
	transmission-remote --exit
	# kill VPN connection
	if [ ! -z $OPENVPN ]; then
		pkill openvpn
	fi
	echo "$(log_date): autoTransmission Complete!"
}


autoTransmission | tee $LOG
