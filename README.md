# autoTransmission
A [transmission](https://transmissionbt.com/about/) wrapper script that manages and schedules torrent downloading for a given number of hours of the day.

## Requirements
``` bash
sudo apt-get install bc shunit2 prgep cron
```
## Usage
```bash
# Start transmission at 11:30pm and add torrents/magnets held in `~/torrent_files`. 
# At 7:30am, remove torrents that have been 100% downloaded and shut down all transmission processes.

sudo ./autoTransmission.sh --setup

./autoTransmission.sh \
   --scheduler 23:30 \
   --torrent_dir ~/torrent_files/ \
   --download_dir ~/Downloads/ \
   --sleep 8h

# Done. Everything should be automated now.
```
## Testing
```bash
cd test/
./test_autoTransmission.sh
```
## Example Commands
```bash
# Add and download all torrent files in the ~/torrent\_files/ directory.
./autoTransmission.sh --torrent_dir ~/torrent_files/

# Add and download torrent files for 8 hours.
./autoTransmission.sh --torrent_dir ~/torrent_files/ --sleep 8h

# Schedule autoTransmission to execute at 11:45pm for 9 hours everyday.
./autoTransmission.sh --scheduler 23:45 --torrent_dir ~/torrent_files/ --sleep 9h

# Download torrents and only remove when the download:upload ratio has reached 1:1.
./autoTransmission.sh --ratio 1.0 --torrent_dir ~/torrent_files/

# Parse --downlimit arguments to transmission-remote.
# NOTE: --args must be last argument parsed to work correctly
./autoTransmission.sh --torrent_dir ~/torrent_files/ --args --uplimit 100
```

# autoVPN
Monitors and reconnects an openvpn VPN every few minutes. Can be configured as a systemd service.
## Requirements
#### Packages
``` bash
sudo apt-get install openvpn systemd
```
#### VPN files
```
# Download your OpenVPN files and create a login.txt containing the username on one line
# and password on the second line. Edit the following line in your `openvpn.ovpn` file:

auth-user-pass /path/to/login.txt

ca /path/to/ca.crt
cert /path/to/client.crt
key /path/to/client.key
```
## Usage
``` bash
# Setup autoVPN systemd service that checks VPN connection every 15 minutes.
sudo ./autoVPN.sh --setup ~/VPN_dir/ --sleep 15m

# Done. VPN reconnection and monitoring should be automated now.
```
## Command Examples
``` bash
# Check VPN connection every 20 minutes.
sudo ./autoVPN.sh --openvpn_dir /path/to/ovpn_dir/ --sleep 20m

# Check VPN every 2 hours and check IP address using ipinfo.io.
sudo ./autoVPN.sh --openvpn_dir /path/to/ovpn_dir/ --sleep 2h --ip_site https://ipinfo.io
```
