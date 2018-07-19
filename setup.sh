#!/bin/bash
# setup.sh; setup autoTransmission and autoVPN

set -euo pipefail

# VARIABLES
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# SUDO CHECK
if [ "$(id -u)" != "0" ]; then
	echo "$(date): This script must be run as root"
	exit 1
fi


# UNIVERSAL FUNCTION
log_date() {
	echo [`date '+%Y-%m-%d %H:%M:%S'`] 
}


# VPN settings
echo "Do you want to set up autoVPN (press anykey)?"
read answer

echo "Where are your .ovpn files located (use absolute path)?"
read OPENVPN_DIR

if [ ! -d $OPENVPN_DIR ]; then
	echo $(log_date): $OPENVPN_DIR is not a directory
	exit 1
fi

# create systemd file
cat << EOF > /lib/systemd/system/autoVPN.service
[Unit]
Description=autoVPN
StartLimitIntervalSec=61
StartLimitBurst=15


[Service]
Type=forking
ExecStart=${HERE}/autoVPN.sh --openvpn_dir $OPENVPN_DIR
ExecStop=/usr/bin/killall openvpn
Restart=always
RestartSec=60
Environment=DISPLAY=:%i
TimeoutStartSec=0

[Install]
WantedBy=default.target
EOF

# enable systemd file
systemctl enable autoVPN.service
echo $(log_date): autoVPN will work on boot now
