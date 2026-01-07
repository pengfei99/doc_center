# Set Up Time Synchronization on Debian


`Time synchronization is essential for ensuring the reliability, security, and functionality` of Debian and 
other Unix-like systems. The **Network Time Protocol (NTP)** is an essential element for time sync that 
synchronizes the clocks of `client computers` with a `time server`.

In debian system, there are three implementations of the NTP:
- ntpd: Implement both server and client
- chrony: Implement both server and client
- timesyncd: Implement only client

Most Linux distributions provide `a ntp client` and `a default configuration` that points to time servers that they maintain. 
By default, in `debian 11`, the default time synchronization client is called **timesyncd**. 

All these clients use the pre-configured ntp server to synchronize time. For example you should probably see the below
 urls in your conf : 
- `2.fedora.pool.ntp.org`
- `0.ubuntu.pool.ntp.org` 


The problem is that you need internet access to do the time synchronization. If your servers do not have internet access
the default configuration will not work.

The purpose of this tutorial is to set a local ntp server. And all client servers use this local ntp server to do the
time syncronization.

## 1.Setup a time server(NTP server)


## 2.Configure a client to synchronize with the time-server

### 2.1 Check the current status of your client computer

You can use below command to check the current date time of your client computer

```shell
# Check time on debian
date

# the output is like
Mon Dec  4 16:16:40 CET 2023

# for more details, you can use
timedatectl status --all

# The output is like
               Local time: Mon 2023-12-04 16:26:16 CET
           Universal time: Mon 2023-12-04 15:26:16 UTC
                 RTC time: Mon 2023-12-04 15:26:16
                Time zone: Europe/Paris (CET, +0100)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no

```

> CET(central european time) is the timezone acronym. 

### 2.2 Configuring a client for time synchronization


#### 2.2.1 Configuration of timesyncd

##### Get current status of systemd-timesyncd

```shell
# get current status of systemd-timesyncd
systemctl status systemd-timesyncd.service

# the output looks like:
systemd-timesyncd.service - Network Time Synchronization
     Loaded: loaded (/lib/systemd/system/systemd-timesyncd.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2023-11-28 15:52:13 CET; 6 days ago
       Docs: man:systemd-timesyncd.service(8)
   Main PID: 386 (systemd-timesyn)
     Status: "Initial synchronization to time server 213.5.132.231:123 (2.debian.pool.ntp.org)."
      Tasks: 2 (limit: 9413)
     Memory: 1.7M
        CPU: 666ms
     CGroup: /system.slice/systemd-timesyncd.service
             └─386 /lib/systemd/systemd-timesyncd

```
> We could notice that this client use ntp server 2.debian.pool.ntp.org to synchronize time

Some other useful command

```shell
# enable at boot	
systemctl enable systemd-timesyncd

# start the service
systemctl start systemd-timesyncd
```


#### Change the ntp server

The main configuration file of systemd-timesyncd.service is located at **/etc/systemd/timesyncd.conf**. We suppose
the ntp server ip is .
```shell
sudo vim /etc/systemd/timesyncd.conf

# add the following line
NTP=10.50.5.57
# you can put multiple line of ntp server, it will be used as backup if the first one does not work.
NTP=...
```

> As timesyncd is a light weight of ntp, it takes only one out of the NTP= list that works, and if all in there fail 
  try the list in FallbackNTP=. **There is no cross server checks for better time sync**. If you want that feature, use
  **ntpd or chrony**.it sta
