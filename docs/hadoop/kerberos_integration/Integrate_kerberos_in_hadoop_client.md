# Integrate kerberos in hadoop client

In this tutorial, we suppose the user identity is managed inside an `AD server`, which delivers `Krb tickets`. 

We suppose we have :

- `AD/Krb` server: The ip address is `10.50.5.64`, ad domain name `casdds.casd`, krb realm name `CASDDS.CASD`, hostname `auth`, fqdn is `auth.casdds.casd`
- `debian server`: ip address is `10.50.5.199`, hostname is `pengfei-hclient`, fqdn is `pengfei-hclient.casdds.casd`

To integrate kerberos in hadoop client, we need to follow the below steps:
- configure debian server to use AD/Krb for sshd authentication
- install hadoop client
- configure hadoop client to use krb ticket as authentication mechanism.

## 1. Configure debian server to use AD/Krb for sshd authentication

The full doc on how to config debian to use AD/Krb for sshd authentication can be found [here](../../adminsys/os_setup/security/04.Configure_ssh_pam_sssd_ad_en.md)

Here we just show a shorter version.


### 1.1 Reset hostname of hadoop-client

The hostname is essential for the server to have a valid FQDN in the domain, so we need to make sure the hostname
is set correctly. Follow the below steps:
- set system hostname
- update /etc/hosts

```shell 
sudo hostnamectl set-hostname pengfei-hclient.casdds.casd

# check the new hostname with below command
hostname

# expected output
pengfei-hclient
```

> you can also directly edit the hostname config file(not recommended) by using `sudo vim /etc/hostname`

Update `/etc/hosts`:

```shell
sudo vim /etc/hosts 

127.0.1.1 hadoop-client.casdds.casd hadoop-client
10.50.5.199	hadoop-client.casdds.casd	hadoop-client

```
> This config is essential, if the host name is not correct, the linux server will join the AD REALM with a bad name


### 1.2 Update system packages in hadoop-client

```shell
sudo apt update 
sudo apt upgrade
```

### 1.3 Change dns server settings in hadoop-client

To join the server into an AD domain, you must use the AD as dns server.

Edit the `/etc/resolv.conf` :

```shell
search casdds.casd
# the ip of the AD/krb server, because it's also the dns
nameserver 10.50.5.64
nameserver 8.8.8.8
```

### 1.4 Install the required packages in hadoop-client

```shell
sudo apt install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin krb5-user oddjob oddjob-mkhomedir packagekit -y
```


### 1.5 Check if the AD domain can be reached or not

```shell
sudo realm discover CASDDS.CASD
```
> - If the error message is realm command is unknown, open a new shell.
> - If the error message is CASDDS.CASD is unknown, check the dns server ip is reachable, and dns server name setup is correct.

### 1.6 Join the server(pengfei-hclient.casdds.casd) to the AD domain
 
To execute the below command, you must have an account with `domain administrator` privilege :

```shell
sudo realm join --user=Administrateur CASDDS.CASD
```

> The join action will:
> 1. create related accounts in `computer` section of AD(AD server side)
> 2. create a keytab file for the linux krb client to connect to the AD/krb server
> If there is no error message, it means your server has joined the domain.
> 
By default, the keytab file is located at `/etc/krb5.keytab`. You can check the content with the below command

```shell
# as the keytab file is protected, so you need sudo right
sudo klist -k /etc/krb5.keytab

# expected output
Keytab name: FILE:/etc/krb5.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   2 PENGFEI-HCLIENT$@CASDDS.CASD
   2 PENGFEI-HCLIENT$@CASDDS.CASD
   2 host/PENGFEI-HCLIENT@CASDDS.CASD
   2 host/PENGFEI-HCLIENT@CASDDS.CASD
   2 host/pengfei-hclient.casdds.casd@CASDDS.CASD
   2 host/pengfei-hclient.casdds.casd@CASDDS.CASD
   2 RestrictedKrbHost/PENGFEI-HCLIENT@CASDDS.CASD
   2 RestrictedKrbHost/PENGFEI-HCLIENT@CASDDS.CASD
   2 RestrictedKrbHost/pengfei-hclient.casdds.casd@CASDDS.CASD
   2 RestrictedKrbHost/pengfei-hclient.casdds.casd@CASDDS.CASD
```

### 1.7 Configure the linux server(pengfei-hclient) account in AD

If the `pengfei-hclient` has success joined the AD domain, you should see the server appears in the `Computer` section in
the AD manager GUI. 

Then right-click on the server->properties-> Select the `Trust this computer for delegation to any service` option in `Delegation`. 

Click on the `Static IP address` option in `Dial-in`, then put the address ip of the `hadoop-client`.

> You can add a new computer in AD manually, but we don't recommend that.

### 1.8 Configure AD/krb, dns 

To make the debian server (pengfei-hclient) fqdn `recognizable` and `reachable` by the other servers in the domain,
we need to configure the dns server 

Check `Step 3: Config AD/Krb, DNS server to well integrate ...` in [here](../../adminsys/os_setup/security/04.Configure_ssh_pam_sssd_ad_en.md)


#### 1.8.1 Check the SPN (Service Principal Name) in Windows server   

Every registered computer in the domain should have a `valid SPN (Service Principal Name)`. You can check the name by 
using the below command. You can open a `powershell prompt` in the `AD/krb` server.

 
```powershell
setspn -L pengfei-hclient

# expected output
Registered ServicePrincipalNames for CN=PENGFEI-HCLIENT,CN=Computers,DC=casdds,DC=casd:
        RestrictedKrbHost/pengfei-hclient.casdds.casd
        RestrictedKrbHost/PENGFEI-HCLIENT
        host/pengfei-hclient.casdds.casd
        host/PENGFEI-HCLIENT

```

> If you don't see any outputs, something went wrong, you should leave and rejoin the realm.


#### 1.8.2 Leave and rejoin the realm

If there are errors that you can't resolve, you can always leave the realm and rejoin

```shell
sudo realm leave CASDDS.CASD

sudo realm join --user=Administrateur CASDDS.CASD
```



### 1.9 Configuration of SSSD, PAM and Kerberos

We will follow the below order to configure each component:
- kerberos client: configure krb client to connect to the target krb Realm
- sshd/pam: configure sshd server to use pam as authentication backend
- pam/sssd: configure pam to use sssd as backend
- sssd/krb: configure sssd to use krb plugin

#### 1.9.1 Configure kerberos client in debian(hadoop-client) server 

```shell
# install the required package
sudo apt install krb5-user

# edit the config file `/etc/krb5.conf`  
sudo vim /etc/krb5.conf
```
Put the below content in the file `/etc/krb5.conf` 

```shell
 [libdefaults]
        default_realm = CASDDS.CASD

        default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
        default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
        permitted_enctypes   = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
        kdc_timesync = 1
        ccache_type = 4
        forwardable = true
        # Fadoua said this must be removed from, otherwise the ticket will not be forwad to the target host 
        # proxiable = true
        ticket_lifetime = 24h
        dns_lookup_realm = true
        dns_lookup_kdc = true
        dns_canonicalize_hostname = false
        rdns = false
         allow_weak_crypto = true


[realms]
        CASDDS.CASD = {
                kdc = 10.50.5.64
                admin_server = 10.50.5.64
        }

[domain_realm]
        .casdds.casd = CASDDS.CASD
        casdds.casd = CASDDS.CASD
```


### 4.2. Configure sshd to use pam 

We need to edit two files:
- `/etc/ssh/sshd_config` (configuration for the ssh server)
- `/etc/ssh/ssh_config` (configuration for the ssh client)

In `/etc/ssh/sshd_config`, enable the below lines
```shell

# disable other authentication methods
ChallengeResponseAuthentication no
PasswordAuthentication no

# use pam as authentication backend
UsePAM yes

# GSSAPI options for sshd server to accept GSSAPI, it's required for the server to accept krb ticket as 
# credentials
# 
GSSAPIAuthentication yes
# Cleans up the Kerberos credentials after the session.
GSSAPICleanupCredentials yes
# Ensures that the SSH client does not strictly check for a valid acceptor name in the Kerberos tickets.
GSSAPIStrictAcceptorCheck no
# Allows the exchange of Kerberos keys for stronger encryption.
GSSAPIKeyExchange yes


X11Forwarding yes

PrintMotd no


# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem       sftp    /usr/lib/openssh/sftp-server

```

> You need to restart the sshd service to enable the new config
> 

```shell
sudo systemctl restart sshd
```

In the `/etc/ssh/ssh_config`, you need to add the below line 
```shell
   Host *
       GSSAPIAuthentication yes
       GSSAPIDelegateCredentials yes
       PasswordAuthentication no
```
> For hadoop-client, the `ssh_config` is not required, because it defines the behaviour of the ssh client.
> It needs to be configured in the ssh client which wants to connect to the hadoop-client ssh server.
> 


### 4.3 Configure pam

All the configuration files for pam are located in `/etc/pam.d/`. The below is the minimum config for the pam
to use sssd daemon as authentication backend.

```shell
### /etc/pam.d/common-auth
sudo: unable to resolve host debian118: Name or service not known
auth      sufficient  pam_unix.so try_first_pass
auth      sufficient  pam_sss.so use_first_pass
auth      required    pam_deny.so
```
```shell
### /etc/pam.d/common-account
sudo: unable to resolve host debian118: Name or service not known
account   required    pam_unix.so
account   sufficient  pam_sss.so
account   required    pam_permit.so
```
```shell
### /etc/pam.d/common-password
sudo: unable to resolve host debian118: Name or service not known
password  sufficient  pam_unix.so
password  sufficient  pam_sss.so
password  required    pam_deny.so
```
```shell
### /etc/pam.d/common-session
sudo: unable to resolve host debian118: Name or service not known
session   required    pam_unix.so
session   optional    pam_sss.so
session   required    pam_mkhomedir.so skel=/etc/skel/ umask=0022
```

### 4.4 Configure sssd

Now we need to configure the sssd daemon. The main config file is in `/etc/sssd/sssd.conf`

```shell
[sssd]
services = nss, pam
domains = casdds.casd
config_file_version = 2

[nss]
homedir_substring = /home

[pam]

[domain/casdds.casd]
ldap_sasl_authid = sssd@CASDDS.CASD
krb5_keytab = /etc/sssd.keytab
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = CASDDS.CASD
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = casdds.casd
use_fully_qualified_names = False
ldap_id_mapping = True
access_provider = ad
ldap_group_nesting_level = 2

```

## 5.configure ssh client on Windows

In windows, there are many ssh clients:
- MobaXterm:
- tabby: https://tabby.sh/
- powershell+openssh
- PuTTY


Configure ssh client 

```shell
# open a notepad
notepad $env:USERPROFILE\.ssh\config

# add the below lines
# * means for all hosts
Host *
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes 
```

You can also define the behaviors host by host, below is an example

```shell
Host pengfei-hclient
    HostName pengfei-hclient.casdds.casd
    User pengfei@casdds.casd
    Port 22
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes 
```

## Step 6 : Test the solution

In our scenario, the user follow the below steps:
1. first login to a Windows server, the first ticket kerberos is generated in the Windows server.
2. user ssh to hadoop-client with the ticket kerberos with option forward ticket
3. user try to access hdfs cluster with the forward kerberos ticket

Suppose you have an account `user` in AD with the privilege to connect to `hadoop client` 
\
### 6.1. Understand the ticket

In linux, you can ask a ticket and check the ticket with the below command

```shell
# ask a new ticket, you need to provide a password associated with the provided principal
kinit user@CASDDS.CASD  

# check the ticket contents
klist -5fea   
```
The option:
- **5**: Show only Kerberos 5 tickets (modern Kerberos version).
- **f**: Show ticket flags (like FORWARDABLE, RENEWABLE, etc.).
- **e**: Display encryption type used for the ticket.
- **a**	Show addresses associated with the ticket (if address-restriction of the ticket is activated).

You should see the below output as the ticket content

```shell
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: user@CASDDS.CASD

Valid starting       Expires              Service principal
03/31/25 10:00:00  03/31/25 20:00:00  krbtgt/CASDDS.CASD@CASDDS.CASD
        Flags: FRI
        Etype (skey, tkt): aes256-cts-hmac-sha1-96, aes256-cts-hmac-sha1-96
        Addresses: 192.168.1.100
```
A kerberos ticket has the below properites:

 - Ticket cache: Location of the ticket. 
 - Default principal: Your Kerberos identity (user@EXAMPLE.COM).
 - Valid starting / Expires: Time range for which the ticket is valid.
 - Service principal: The Kerberos service this ticket is for. (krbtgt/CASDDS.CASD@CASDDS.CASD is a tgt issued by CASDDS.CASD the kdc server)
 - Flags (-f option): F = Forwardable (Can be forwarded to another machine). R = Renewable (Can be extended before expiration). I = Initial (Freshly obtained).
 - Encryption type (-e option): aes256-cts-hmac-sha1-96, means AES-256 encryption with SHA-1 HMAC.
 - Addresses (-a option): Shows the IP addresses associated with the ticket (if address-restricted).

You can ask ticket with special options:

```shell
# below command ask a Forwardable, Renewable for a 7 day validity
kinit -f -r 7d

```
> Based on the kdc configuration, it may or may not generate the ticket.

### 6.2. Connexion SSH

From windows, if the server has joined the domain, windows will generate a kerberos ticket after user logon:

```shell
# check the user ticket
klist -5fea

# for windows ssh client
# -K active la délégation Kerberos
ssh -K user@debian.casdds.casd  

# for linux ssh client
ssh -o GSSAPIDelegateCredentials=yes user@debian.casdds.casd
```


## Appendix :

###  ACL for /etc/sssd/sssd.conf

The Permissions for `/etc/sssd/sssd.conf` must be `600` :

```shell
sudo chmod 600 /etc/sssd/sssd.conf
```
