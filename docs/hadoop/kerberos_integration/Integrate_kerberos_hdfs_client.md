# Integrate kerberos to hdfs client


## Install the required lib

```shell
sudo apt install sssd sssd-tools libnss-sss libpam-sss krb5-user oddjob oddjob-mkhomedir
```

## Configure ssh by using pam, sssd, krb

The workflow of user authentication via ssh, pam, ssd, krb
```shell
# client side
# user get a service ticket, and send it's id and ticket to the ssh server

# server side
# sshd receives the user query, then delegate it to PAM, PAM to sssd, sssd use krb client 
# to send verification query to AD. 
# sssd needs 
sshd → PAM → sssd → Kerberos → AD
```

### Configure SSH

The main config file of `SSH server` is located at `/etc/ssh/sshd_config`

Below is a minimum sshd_config file
```ini
Include /etc/ssh/sshd_config.d/*.conf

PermitRootLogin no

ChallengeResponseAuthentication no

# GSSAPI options
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
GSSAPIStrictAcceptorCheck no
AllowTcpForwarding yes
AllowAgentForwarding yes
GssapiKeyExchange yes

UsePAM yes
UseDNS yes

X11Forwarding yes

PrintMotd no

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

```

### Configure Pam (Pluggable Authentication Modules) 

`pam` has a list of configuration files(located in `/etc/pam.d/`):
- **common-auth**: user authentication 
- **common-account**: User account management
- **common-password**: Allow user to modify password.
- **common-session**: user session settings
Those `common-*` files are system-wide PAM policy used by:
- SSH
- login
- sudo
- GUI login
- cron
- everything

The goal is to configure Pam to use sssd as authentication backend.

The `/etc/pam.d/sshd` file which defines how ssh delegate authentication to pam

```ini
# PAM configuration for the Secure Shell service

# Standard Un*x authentication.
@include common-auth

# Disallow non-root logins when /etc/nologin exists.
account    required     pam_nologin.so

# Uncomment and edit /etc/security/access.conf if you need to set complex
# access limits that are hard to express in sshd_config.
# account  required     pam_access.so

# Standard Un*x authorization.
@include common-account

# SELinux needs to be the first session rule.  This ensures that any
# lingering context has been cleared.  Without this it is possible that a
# module could execute code in the wrong domain.
session [success=ok ignore=ignore module_unknown=ignore default=bad]        pam_selinux.so close

# Set the loginuid process attribute.
session    required     pam_loginuid.so

# Create a new session keyring.
session    optional     pam_keyinit.so force revoke

# Standard Un*x session setup and teardown.
@include common-session

# Print the message of the day upon successful login.
# This includes a dynamically generated part from /run/motd.dynamic
# and a static (admin-editable) part from /etc/motd.
session    optional     pam_motd.so  motd=/run/motd.dynamic
session    optional     pam_motd.so noupdate

# Print the status of the user's mailbox upon successful login.
session    optional     pam_mail.so standard noenv # [1]

# Set up user limits from /etc/security/limits.conf.
session    required     pam_limits.so

# Read environment variables from /etc/environment and
# /etc/security/pam_env.conf.
session    required     pam_env.so # [1]
# In Debian 4.0 (etch), locale-related environment variables were moved to
# /etc/default/locale, so read that as well.
session    required     pam_env.so envfile=/etc/default/locale

# SELinux needs to intervene at login time to ensure that the process starts
# in the proper default security context.  Only sessions which are intended
# to run in the user's context should be run after this.
session [success=ok ignore=ignore module_unknown=ignore default=bad]        pam_selinux.so open

# Standard Un*x password updating.
@include common-password
```
> You can notice this files uses the `common-*` files. So no need to change it

#### common-auth

The simplest config example :

```shell
auth      sufficient  pam_unix.so
auth      sufficient  pam_sss.so use_first_pass
auth      required    pam_deny.so
```
pam_unix.so: Uses local account to authenticate users
pam_sss.so use_first_pass: Uses SSSD as first method to authenticate users.
pam_deny.so: Denies access if all the above authentication method fails.
pam_permit.so: Allows authentication if all previous steps succeed.


#### common-account

This controls how the user account can interact with the system. 
Below is a simple config example. 
```shell
account   required    pam_unix.so
account   sufficient  pam_sss.so
account   required    pam_permit.so
```

> **don't** add `account requisite  pam_deny.so` in the config, otherwise you can no longer become root with sudoers right.

####  common-password: 

Allow user to modify password.

```shell
password  sufficient  pam_unix.so nullok md5 shadow use_authtok
password  sufficient  pam_sss.so try_first_pass
password  required    pam_deny.so

```

> This configuration is not enough for user to change password. You need to change sssd, ldap/kerberos config to 
> allow users to change their passwords through sssd, Kerberos/LDAP.
 
####  common-session

```shell
session   required    pam_unix.so
session   optional    pam_sss.so
session   required    pam_mkhomedir.so skel=/etc/skel/ umask=0022

```
- pam_mkhomedir.so: Create a home directory on first login if it doesn’t exist with umask=0022.
- pam_sss.so: Ensures SSSD session modules are applied.

### Configure SSSD (System Security Service Daemon)

SSSD is the bridge between the Linux server and AD. SSSD verifies the user kerberos ticket with the AD server, then
send back reponse to the PAM. 
The main config file of SSSD is located at `/etc/sssd/sssd.conf`

```ini
[sssd]
domains = CASDDS.CASD
config_file_version = 2
services = nss, pam, ssh

[nss]
homedir_substring = /home

[pam]

[domain/CASDDS.CASD]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = CASDDS.CASD
#realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u
ad_domain = CASDDS.CASD
use_fully_qualified_names = False
ldap_id_mapping = False
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_group_nesting_level = 2
ldap_sasl_authid = deb13-spark1$@CASDDS.CASD
krb5_keytab = /etc/security/keytabs/deb13-spark1.keytab
```

### Configure krb client
The main conf file of krb client is located at `/etc/krb5.conf`

Below is an example
```ini
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
udp_preference_limit = 0


[realms]
        CASDDS.CASD = {
                kdc = 10.50.5.64
                admin_server = 10.50.5.64
        }
[domain_realm]
        .casdds.casd = CASDDS.CASD
        casdds.casd = CASDDS.CASD
```


### 2.4 Configure NSS

Name Service Switch (NSS) is the layer in Linux that helps system to lookup username and group information.
By default, without NSS, the system checks `/etc/passwd` only. With NSS, we can do `user lookup → files → sssd → ldap/AD → winbind → …`

> In this tutorial, the objective is to ensure system uses SSSD to do user and group lookup in AD.

The NSS (Name Service Switch) main config is located at `/etc/nsswitch.conf`:

The following config is a simple example tells Linux to check both local files (/etc/passwd) and SSSD for user information.

```shell
sudo vim /etc/nsswitch.conf

passwd:         files sss
group:          files sss
shadow:         files sss
gshadow:        files

hosts:          files dns
networks:       files

protocols:      files
services:       files sss
ethers:         files
rpc:            files

netgroup:       nis sss
automount:  sss
```

```shell
# check user and group information 
getent passwd <user-name/uid>
getent group <group-name/gid>
```

> NSS is essential for Kerberos authentication. Because Linux must map `user@REALM → UID/GID → local session`, If
> user is unknown, the authentication fails