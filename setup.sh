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


# MSG
echo "$(log_date): transmission settings and .bashrc file will be altered. press any key to continue":
read anykey

# AUTHENTICATION
# change the transmission settings to not require authorisation
service transmission-daemon stop
SETTINGS="/var/lib/transmission-daemon/.config/transmission-daemon/settings.json"
if grep '"rpc-authentication-required": true' $SETTINGS; then
	echo "$(loag_date): changing transmission authentication settings."
	sed -i 's/"rpc-authentication-required": true,/"rpc-authentication-required": false,/g' $SETTINGS
else
	echo "$(log_date): Authentication already disabled."
fi


# BASH ALIAS
if grep --quiet "alias autoTransmission=" ${HOME}/.bashrc; then
	echo $(log_date): autoTransmission alias already present in the users BASHRC
else
	echo $(log_date): appending autoTransmission to bashrc
	echo alias autoTransmission="${HERE}/autoTransmission.sh" >> ${HOME}/.bashrc
fi


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
Description=init_autoVPN
Documentatin=man:emacs(1) info:Emacs


[Service]
Type=forking
ExecStart=${HERE}/autoVPN.sh --openvpn_dir $OPENVPN_DIR
ExecStop=/usr/bin/killall openvpn
Restart=always
Environment=DISPLAY=:%i
TimeoutStartSec=0

[Install]
WantedBy=default.target
EOF

# enable systemd file
systemctl enable autoVPN.service
echo $(log_date): autoVPN will work on boot now
