# To Do
## autoVPN
- log outputs openvpn messages only; no atoVPN log messages end up in the log file.
## autoTransmission
- parsings `./autoTransmision.sh -t ~/trrt/ -d ~/Downloads --sleep 10s --args --downlimit 10` results in an ordering error for arg. It seems to misunderstand the --downlimit as being -d (showrthand for --download\_dir in autoTransmission).
