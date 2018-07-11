# autoTransmission
A [transmission](https://transmissionbt.com/about/) wrapper script that automates and schedules torrent downloading.

## Usage
Add and download all torrent files in the ~/torrent\_files/ directory.
```bash
./autoTransmission.sh --torrent_dir ~/torrent_files/
```
Add and download torrent files for 8 hours.
```bash
./autoTransmission.sh --torrent_dir ~/torrent_files/ --sleep 8h
```
Connect to a VPN while adding and downloading torrent files (requires root).
```bash
sudo ./autoTransmission.sh --torrent_dir ~/torrent_fles/ --vpn_dir ~/open_vpn_files/
```

## Setup
### OpenVPN
Download your OpenVPN files and create a login.conf containing the username on one line and password on the second line (make sure it is only readable by the root user). Add the following to your opnevpn.ovpn file:
```
auth-user-pass /path/to/login.conf

ca /path/to/ca.crt
cert /path/to/client.crt
key /path/to/client.key
```
### Scheduling
You can schedule this script to run everyday by editing the below cron command and placing it into your crontab file with `crontab -e`.
```
45 23 * * * ${HOME}/.profile; .  ${HOME}/.bashrc; ${HOME}/bin/autoTransmission.sh --torrent_dir <dir> --download_dir <dir>
```
### Transmission Authentication
If you dont want to run this script then you will have to alter the /etc/transmission-daemon/settings.json file. In the file `/etc/transmission-daemon/settings.json` change `rpc-authentication-required: true`to `rpc-authentication-required: false`.

