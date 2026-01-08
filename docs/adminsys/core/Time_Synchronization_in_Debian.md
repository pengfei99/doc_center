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
Tue 28 May 2024 09:54:04 AM CEST
# The output shows the current time as well as the current date. The current time in the output is usually in 
# Coordinated Universal Time (UTC). UTC is the time at zero degrees longitude and is accepted as a universal timezone.
# In the above example, we have `timezone CEST(Central European Summer Time)`.

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
> 

The date command prints the UTC zone by default. However, users sometimes need to change the timezone on Debian, 
which is done with the **timedatectl** command. Take the following steps to change the timezone on Debian:

```shell
# 1. List the available timezones on Debian:
timedatectl list-timezones

# 2. Navigate the output with the space bar and b key. 

# 3. Press q to quit

# 4. Change the timezone with the following command:
sudo timedatectl set-timezone <timezone>

# change it to UTC
sudo timedatectl set-timezone UTC

# change it to CEST
sudo timedatectl set-timezone Europe/Paris

# 5. Verify the change with date:
date
# you should see now the timezone is UTC or CEST
```

### 2.2 Configuring a client for time synchronization

#### 2.2.0 The legacy ntpd daemon

Debian runs the standard Network Time Protocol daemon (ntpd) to sync the system time with external time-servers. 
While NTP is the protocol for synchronizing time.

In old version of debian, `ntpd` is the program which implements the NTP protocol.
In recent version, `timesyncd` is used for time sync.

To confirm ntpd is running, execute the systemctl command:

```shell
# show the status of ntpd daemon
sudo systemctl status ntp

# list the time server which the ntpd daemon use to sync time
# The -p argument specifies info about the NTP servers to which ntpd currently connects to.
ntpq -p


```

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

When starting, systemd-timesyncd will read the configuration file from `/etc/systemd/timesyncd.conf`, which looks like this:

```shell
vim /etc/systemd/timesyncd.conf

# file content
[Time]
#NTP=
#FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
#...
```

To add time-servers or change the provided ones, uncomment the relevant line and list their `host name or IP` separated 
by a space. Alternatively, you can use a configuration snippet in /etc/systemd/timesyncd.conf.d/*.conf.

In this tutorial, we change it directly in **/etc/systemd/timesyncd.conf**

Below is a basic example of timesyncd.conf

First we configure a main time-server pool.
Then, we configure a fallback time-server pool in case all main time-server are down.

```shell
[Time]
NTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 0.fr.pool.ntp.org
```

Save the config file, and restart the service. To verify your configuration:

```shell
timedatectl show-timesync --all

# an output example
LinkNTPServers=
SystemNTPServers=
FallbackNTPServers=ntp.ubuntu.com
ServerName=ntp.ubuntu.com
ServerAddress=91.189.91.157
RootDistanceMaxUSec=5s
PollIntervalMinUSec=32s
PollIntervalMaxUSec=34min 8s
PollIntervalUSec=34min 8s
NTPMessage={ Leap=0, Version=4, Mode=4, Stratum=2, Precision=-24, RootDelay=41.641ms, RootDispersion=900us, Reference=84A36001, OriginateTimestamp=Tue 2024-05-28 10:47:04 CEST, ReceiveTimestamp=Tue 2024-05-28 10:47:04 CEST, TransmitTimestamp=Tue 2024-05-28 10:47:04 CEST, DestinationTimestamp=Tue 2024-05-28 10:47:04 CEST, Ignored=no PacketCount=1500, Jitter=1.508ms }
Frequency=442282
```

> As timesyncd is a light weight of ntp, it takes only one out of the NTP= list that works, and if all in there fail 
  try the list in FallbackNTP=. **There is no cross server checks for better time sync**. If you want that feature, use
  **ntpd or chrony**.it sta


## ## 4: Switching from ntpd to timesyncd

Normally, you don't need to do this. (**ntpd is replaced by timesyncd by default**).

**Timesyncd** is a `lightweight ntpd alternative`, which is simpler to configure, more efficient, and more secure. 
Furthermore, timesyncd also integrates better with systemd. This feature makes it easy to manage using the systemd commands.

However, **timesyncd cannot be used as a time-server**, and it is less sophisticated in keeping the system time in sync. 
These features make the program a less suitable choice for systems in need of accuracy and reliability. 
Complex real-time distributed systems generally work better with ntpd.


```shell
# remove the nptd daemon
sudo apt purge ntp

# install the timesyncd daemon 
sudo apt install systemd-timesyncd

# start the timesyncd service
sudo systemctl start systemd-timesyncd

# check the status
sudo systemctl status systemd-timesyncd

# show the current time
timedatectl

# output example
  Local time: mar. 2024-05-28 10:10:45 CEST
           Universal time: mar. 2024-05-28 08:10:45 UTC 
                 RTC time: mar. 2024-05-28 08:10:44     
                Time zone: Europe/Paris (CEST, +0200)   
System clock synchronized: yes                          
              NTP service: active                       
          RTC in local TZ: no       
```

## 5 Configure timesyncd to sync with given timeservers

