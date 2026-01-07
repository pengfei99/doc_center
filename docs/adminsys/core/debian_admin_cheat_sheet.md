# Debian amdin cheat sheet

## 1. Network setup

If you have a dhcp server, it will distriubt you an IP address. But sometimes, you don't have a dhcp server. So you need to setup a static IP address.

### 1.1 Get available network interfaces

```shell
# show all activated interfaces
ip a

# show all interfaces, can be up or down 
ip -c link
```

### 1.2 Configure static IP (tested on debian 10/11)

The main config of network interfaces are located at `/etc/network/interfaces`
```shell
suod vim /etc/network/interfaces

```
You should see below text. In this example, the name of the interface is `eth0` and it uses `dhcp`

```text
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp
```

Change it from `dhcp` to **static**. You need to add all the required informaton for the ip address to work.

Below is an example: (ip: 10.50.5.58, mask: 255.255.255.0, gateway: 10.50.0.1, dns:10.50.0.10)

```text
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet static
        address 10.50.5.58/24
        gateway 10.50.0.1
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers 10.50.0.10 8.8.8.8
        dns-search casd.eu casd.local
```

Note, you need to restart the service to activate the new configuration

```shell
systemctl restart networking.service; ifup eth0
```
### 1.3 DNS configuration

The dns configuration is located at `/etc/resolv.conf`. Below is an example

```text
search casd.local
nameserver 10.50.0.10
nameserver 8.8.8.8
```

Normally, you don't need to edit this file directly. Debian provides two packages(`openresolv and resolvconf`), each of which contains a program named `resolvconf`, which may be used to control (or outright prevent) the alteration of the /etc/resolv.conf file by various networking programs. They conflict with each other, so you have to pick at most one of them.

So if you modified the `/etc/network/interfaces` and restart network.service, the program ((`openresolv or resolvconf`)) will update the `/etc/resolv.conf`.

You can view it to see exactly which dns you are using.


## 2. Apt configuration
 
If your apt can't find any package, it means your repo is not pointing at the right server url.
You need to edit `/etc/apt/sources.list`, and add appropriate repo url.
Below is the minimun setup for apt to work.

```text

deb http://deb.debian.org/debian/ bullseye main
deb-src http://deb.debian.org/debian/ bullseye main
deb http://security.debian.org/debian-security bullseye-security main contrib
deb-src http://security.debian.org/debian-security bullseye-security main contrib
deb http://deb.debian.org/debian/ bullseye-updates main contrib
deb-src http://deb.debian.org/debian/ bullseye-updates main contrib

```

## 3. Security

### Add user to sudoer list

Solution1: The easiest way is to add user to the sudoer group

```shell
# loign as root, because usermod file is in /usr/sbin
su -

# add user to the sudoer group
usermod -aG sudo user fbar

# To ensure that the user has been added to the group
sudo whoami
```

Solution2: You can also edit the `/etc/sudoers` (always use **visudo**)

```shell
visudo

# in the file /etc/sudoers, add the following line
username  ALL=(ALL) NOPASSWD:ALL

# save and quit the visudo editor
```

Note the user need to logout and re login to have the sudo group.


### Add trusted root ca
https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-a-certificate-authority-ca-on-debian-11

```shell
sudo cp /tmp/ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# you can force the refresh of the trusted ca store
```
