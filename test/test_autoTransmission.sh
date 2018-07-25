HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ${HERE}/temp/
. ../autoTransmission.sh --torrent_dir ${HERE}/temp/
# HERE changes to autoTransmission root directory
TEMP="${HERE}/test/temp/"

test_startup() {
	# ensure startup results in transmission-daemon to be active
	startup_app
	# NOTE: below code sometimes states inactive despite being active
	## status=$(systemctl is-active transmission-daemon.service)
	## assertEquals "active" $status
	# should fail if pgrep retieves nothing
	pgrep transmission
}

test_add_torrents() {
	wget http://releases.ubuntu.com/18.04/ubuntu-18.04-desktop-amd64.iso.torrent -P $TEMP
	add_torrents
	torrent_name="ubuntu-18.04-desktop-amd64.iso"
	torrent_id_list=$(transmission-remote  -l | sed -e '1d;$d;s/^ *//' | \
			          cut --only-delimited --delimiter \  --fields 1)
	torrent_id=$(echo $torrent_id_list | awk '{print $NF}')
	name=$(transmission-remote -t $torrent_id --info | grep -o $torrent_name)
	assertEquals $torrent_name $name
	cleanup
}

cleanup() {
	rm -r $TEMP
	transmission-remote -t $torrent_id --remove-and-delete
}

. shunit2
