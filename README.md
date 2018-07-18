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
Schedule autoTransmission to execute at 11:45pm for 9 hours everyday.
```bash
./autoTransmission.sh --scheduler 23:45 --torrent_dir ~/torrent_files/ --sleep 9h
```
Parse --downlimit arguments to transmission-remote.
```bash
# NOTE: --args must be last argument parsed to work correctly
./autoTransmission.sh --torrent_dir ~/torrent_files/ --args --downlimit 10
```

## Setup
The setup script creates an autoTransmission alias, alters the transmission-daemon settings to not need authentication and creates a VPN systemd service.
### OpenVPN
Setting up a VPN script as a systemd service is possible by following the below instructions.

Download your OpenVPN files and create a login.txt containing the username on one line and password on the second line. Add the following to your opnevpn.ovpn file:
```
auth-user-pass /path/to/login.txt

ca /path/toca.crt
cert /path/to/client.crt
key /path/to/client.key
```

sudo ./setup.sh
