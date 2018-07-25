# autoTransmission
A [transmission](https://transmissionbt.com/about/) wrapper script that manages and schedules torrent downloading for certain hours of the day.

## Requirements
``` bash
sudo apt-get install bc shunit2 prgep cron
```
## Usage
Start transmission at 11:30pm and add torrents/magnets held in `~/torrent_files`. At 7:30am, remove torrents that have been downloaded to 100% and shut down all transmission processes.
```bash
sudo ./autoTransmission.sh --setup
./autoTransmission.sh --scheduler 23:30
./autoTransmission.sh \
   --torrent_dir ~/torrent_files/ \
   --download_dir ~/Downloads/ \
   --sleep 8h
```
## Setup
``` bash
sudo ./autoTransmission.sh --setup
```
## Testing
Ensure shUnit2 is installed.
```bash
cd test/
./test_autoTransmission.sh
```
## Example Commands
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
Download torrents and only remove when the download:upload ratio has reached 1:1
```bash
./autoTransmission.sh --ratio 1.0 --torrent_dir ~/torrent_files/
```
Parse --downlimit arguments to transmission-remote.
```bash
# NOTE: --args must be last argument parsed to work correctly
./autoTransmission.sh --torrent_dir ~/torrent_files/ --args --downlimit 10
```

# autoVPN
Monitors and reconnects an openvpn VPN every few minutes as a systemd service.
## Requirements
``` bash
sudo apt-get install openvpn
```

## Usage
Check VPN connection every 20 minutes.
``` bash
./autoVPN.sh --openvpn_dir /path/to/ovpn_dir/ --sleep 20m
```
Check VPN every 2 hours and check IP address using ipinfo.io.
``` bash
./autoVPN.sh --openvpn_dir /path/to/ovpn_dir/ --sleep 2h --ip_site https://ipinfo.io
```
## Setup
Setup autoVPN as a systemd service.
### OpenVPN files
Download your OpenVPN files and create a login.txt containing the username on one line and password on the second line. Add the following to your openvpn.ovpn file:
```
auth-user-pass /path/to/login.txt

ca /path/to/ca.crt
cert /path/to/client.crt
key /path/to/client.key
```
### Execution
Setup autoVPN systemd service that checks VPN connection every 15 minutes
``` bash
sudo ./autoVPN.sh --setup ~/VPN_dir/ --sleep 15m
sudo systemctl start autoVPN
```
### Removing
```bash
sudo systemctl stop autoVPN
sudo systemctl disable autoVPN
sudo rm /lib/systemd/system/autoVPN.service
sudo systemctl daemon-reload
sudo systemctl reset-failed
```
