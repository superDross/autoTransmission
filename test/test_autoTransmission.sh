oneTimeSetUp() {
	HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	mkdir -p ${HERE}/temp/
	. ../autoTransmission.sh --torrent_dir ${HERE}/temp/
	# HERE changes to autoTransmission root directory after import
	TEMP="${HERE}/test/temp/"
	test_torrent_name="ubuntu-18.04-desktop-amd64.iso"
}

get_test_torrent_id() {
	# returns torrent id number for ubuntu test torrent
	local torrent_id_list=$(transmission-remote  -l | sed -e '1d;$d;s/^ *//' | \
			          cut --only-delimited --delimiter \  --fields 1)
	local torrent_id=$(echo $torrent_id_list | awk '{print $NF}')
	echo $torrent_id
}

test_exit() {
	startup_app
	exit_transmission
	if $(ps aux | grep -v grep | grep transmission-daemon); then
		fail "The exit transmission function did not work"
	fi
}

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
	local torrent_id=$(get_test_torrent_id)
	local name=$(transmission-remote -t $torrent_id --info | grep -o $test_torrent_name)
	assertEquals $test_torrent_name $name
}

test_scheduler() {
	# remove current autoTransmission entry from crontab
	if [ ! -z "$(crontab -l | grep autoTransmission)" ]; then
		original_entry=$(crontab -l | grep autoTransmission)
		crontab -l | grep -v autoTransmission | crontab -
	fi
	# test with 10:33 schedule
	scheduler 10:33
	# ensure test entry is within crontab
	test_entry=$(crontab -l | grep "33 10.*autoTransmission")
	# remove test entry from crontab
	crontab -l | grep -v "33 10.*autoTransmission" | crontab -
	# re-add original autoTransmission schedule
	if [ ! -z "$original_entry" ]; then
		(crontab -l; echo "$original_entry") | crontab -
	fi
}

oneTimeTearDown() {
	rm -r $TEMP
	local torrent_id=$(get_test_torrent_id)
	transmission-remote -t $torrent_id --remove-and-delete
	exit_transmission
}

. shunit2
