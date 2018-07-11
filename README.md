## OpenVPN Setup
Download your OpenVPN files and create a login.conf containing the username on one line and password on the second line (make sure it is only readable by root). Add the following to your opnevpn.ovpn file:
```
auth-user-pass /path/to/login.conf

ca /path/to/ca.crt
cert /path/to/client.crt
key /path/to/client.key
```

need to find away to run openvpn without root

## Transmission
Deactivate the auth in this file ```/etc/transmission-daemon/settings.json``` by changing ```rpc-authentication-required: false```.
