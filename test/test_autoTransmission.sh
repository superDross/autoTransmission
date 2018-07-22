. ../autoTransmission.sh --torrent_dir ${HOME}/Downloads/

test_startup() {
	# ensure startup results in transmission-daemon to be active
	startup_app
	status=$(systemctl is-active transmission-daemon.service)
	assertEquals "active" $status
}

. shunit2
