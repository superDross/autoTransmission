# Alternative
If you are okay with downloading all the time and only limiting download speeds during waking hours then follow the below instructions.

## Daemon Settings
The daemon settings can be found at `/var/lib/transmission-daemon/.config/transmission-daemon/settings.json`.
In the settings you can change the download dir to: 
```bash
"download-dir": "/media/osmc/PRINCE/Downloads/",
```
Add watch directory to end of settings file:
```bash
    "watch-dir": "/home/osmc/trrt/",
    "watch-dir-enabled": true
```
## Remove Script
Add the below script to `~/bin/remove_torrents`.
```bash
#!/bin/bash

remove_torrents() {
	torrent_id_list=$(transmission-remote  -l | sed -e '1d;$d;s/^ *//' | \
			cut --only-delimited --delimiter \  --fields 1)
	# remove downloaded torrents and restart 'Stopped' torrents
	for torrent_id in $torrent_id_list; do
		torrent_info=$(transmission-remote -t $torrent_id --info)
		downloaded=$(echo $torrent_info | grep "Percent Done: 100%")
		stopped=$(echo $torrent_info | grep "State: Stopped")
		torrent_name=$(echo $torrent_info | grep Name | cut -d : -f 2)
		# remove torrent only if downloaded = 100%
		if [ "$downloaded" != "" ]; then
			transmission-remote  -t $torrent_id --remove
			echo "$torrent_name successfully downloaded "
			echo "Removing $torrent_name from torrent list"
		# restart torrent if stopped
		elif [ "$stopped" != "" ]; then
			transmission-remote -t $torrent_id -s
			echo "Restarting $torrent_name"
		fi
	done
}

remove_torrents
```

## Crontab
Alter to download at maximum speed during sleeping hours and at 5MB/s during waking hours
```
45 23 * * * /home/david/.profile; .  /home/david/.bashrc; transmission-remote -D -U
00 06 * * * /home/david/.profile; .  /home/david/.bashrc; transmission-remote -d 5000 -u 100
01 06 * * * /home/david/.profile; .  /home/david/.bashrc; /home/osmc/bin/remove_torrents.sh
```

## Finally
`sudo servce transmission-daemon restart`
