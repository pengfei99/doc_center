# Logging on Debian 13

`Debian 13 (Trixie)` uses systemd as the init system, which means `logging is primarily handled by systemd-journald`
instead of `traditional syslog daemons like rsyslog or sysklogd`. By default, files like /var/log/auth.log and 
/var/log/syslog are not created unless you install and configure a syslog service (e.g., rsyslog). This is why you 
don't see them. The `systemd-journald` stores logs in a **binary format** in `/var/log/journal/` 
(or /run/log/journal/ for volatile storage). 


## show logs of a service

You can access the logs by using the **journalctl command**, which is powerful for `filtering, searching, and viewing logs`
in real-time. For example, for viewing SSH and Authentication Logs with journalctl, we need to first identify the 
name of daemon, in our case it's `ssh`.

```shell
# This shows all logs for the SSH unit (systemd service).
sudo journalctl -u ssh

# Add -f for real-time tailing
sudo journalctl -u ssh -f

# To see only recent(1 hour ago) logs
sudo journalctl -u ssh --since "1 hour ago".
```

If you want to monitor the log of sssd, you need to use `sssd` as name
```shell
sudo journalctl -u sssd 
```
## Filtering the log

If you want to monitor logs of multiple services at the same time. You can use the below pattern
```shell
# show all logs of the server, then filter by the keyword.
sudo journalctl | grep -i "keyword".

# for example, if I want to find all logs about gssapi,
sudo journalctl | grep -i "gssapi".
```

## Change log level

The log level is controlled by each service/daemon which generates the logs

For example, if you want to increase Log Verbosity of ssh, you need to edit `/etc/ssh/sshd_config`
and, add `LogLevel DEBUG3` in it. After restart the daemon `sudo systemctl restart ssh`, you should see more logs.



For SSSD, you need to edit `/etc/sssd/sssd.conf` under [sssd] section, add `debug_level = 9`, then 
`sudo systemctl restart sssd` and check sudo journalctl -u sssd.

## Export logs to file

To export Logs to a text File, you can use the below command.
```shell
sudo journalctl -u ssh > /tmp/ssh_logs.txt
```