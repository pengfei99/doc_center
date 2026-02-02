# gMSA accounts in AD

## 1. AD accounts introduction

In AD, we have three different types of accounts:
- a user account
- a computer account
- a gMSA

Each account can have one or multiple SPN, but the `SPN ownership model are different`.

- Computer account:	One computer account(host) has one SPN(one host identity).
- User account:	One user account has one SPN(One service on a specific host).
- gMSA:	One gMSA account has multiple SPN(One service on multiple hosts).

## 2. What is gMSA?

`gMSA (Group Managed Service Account)` is a service account inside AD where the AD will manage the password(e.g. password expiration, regeneration, etc.) automatically.

It provides the below features:

- password rotation(e.g. every day, every hour, etc.) automatically
- Non-interactive
- Kerberos-native
- Multiple SPNs(service principal name) for one gMSA account

> gMSA has specific rules on SPNs, for example

## 3. How to create a gMSA account?

To create a gMSA account in AD, we need three steps:
- a KDS root key (one-time per forest)
- a security group that is allowed to retrieve the password
- the gMSA account itself

### 3.1 Create the KDS root key (run once per domain)

The `KDS root key` is the cryptographic foundation that lets Active Directory generate and rotate gMSA passwords 
without storing them. **Without it, gMSA cannot exist.**

You only create it once in your domain. After creation, it becomes part of AD’s cryptographic state. All domain 
controllers replicate it and use it forever to generate gMSA credentials.

> Creating multiple root keys is allowed but unnecessary unless:
> - you are rotating cryptographic infrastructure 
> - recovering from compromise 
> - doing advanced lifecycle management 
> For most environments, one root key per forest for years

```powershell
# Run on a domain controller:
Add-KdsRootKey -EffectiveImmediately


# In production you normally wait 10 hours for replication. For lab/testing, you can skip the 10 hours policy
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))
# AD waits ~10 hours before allowing gMSA creation. Because, the key must replicate to all domain controllers. 
# If a DC doesn’t have it yet, it cannot compute passwords consistently.
# The 10 hours delay ensures cryptographic consensus.

# Verify:
Get-KdsRootKey

# expected output
AttributeOfWrongFormat :
KeyValue               : {210, 221, 233, 90...}
EffectiveTime          : 11/11/2025 14:39:54
CreationTime           : 12/11/2025 14:39:54
IsFormatValid          : True
DomainController       : CN=VTL,OU=Domain Controllers,DC=casdds,DC=casd
ServerConfiguration    : Microsoft.KeyDistributionService.Cmdlets.KdsServerConfiguration
KeyId                  : c5a2a047-edbc-d3c7-67d0-d22dece421d6
VersionNumber          : 1

```

### 3.2 Create security group for Linux hosts

This group controls which machines are allowed to use the gMSA. If Linux servers are not domain joined, you still 
need a group placeholder. Later you grant retrieval permissions explicitly.

```powershell
New-ADGroup `
  -Name "gmsa-hadoop-hosts" `
  -GroupScope Global `
  -Path "CN=Users,DC=example,DC=com"
```

### 3.3 Create gMSA account

```powershell
# 
New-ADServiceAccount `
  -Name "deb13-spark1" `
  -DNSHostName "deb13-spark1.casdds.casd" `
  -PrincipalsAllowedToRetrieveManagedPassword "gmsa-hadoop-hosts" `
  -KerberosEncryptionType AES256,AES128
```



## Debug sssd

```shell
# check config validity
sudo sssctl config-check

# check domain status
sudo sssctl domain-status casd.fr




```

## 2.4 Create a daemon to sync gMSA account credential(gMSAd)

You can find the project github page [here](https://github.com/cea-sec/gmsad/tree/main)


### 2.4.1 Create local account to run gMSAd

It's recommended to run the gMSA daemon with a specific service account

```shell
# create group
addgroup --system gmsa

# create service account
adduser --system --no-create-home --shell=/usr/sbin/nologin --ingroup=gmsa gmsa
```



### 2.4.2 Install the gMSA binary

```shell
sudo apt-get install -y python3 python3-pip python3-venv libkrb5-dev krb5-user sssd-ad sssd-tools

# create a virtual env
python3 -m venv gmsad-venv

# activate the venv
source gmsad-venv/bin/activate

# install the gmsad via .wheel files inside the venv
pip install --no-index --break-system-packages -f ./ gmsad-0.2.0-py3-none-any.whl

# or via repo pypi
pip install --break-system-packages gmsad

# check the gmsad version
which gmsad

pip show gmsad

```
> we recommend you to install the gmsad inside a venv
> 
### 2.4.3 Configure gMSAd

The main configuration file of gMSAd is located at `/etc/gmsad.conf`
```ini
[global]
realm = CASDDS.CASD
domain = casdds.casd
gMSA_domain = CASDDS.CASD

# Configuration LDAP
ldaps = ldaps://10.50.5.64:636

# Authentification of 
# keep in mind the CASE is important, if you see the principal does not exist, change the case to Capital letters
principal = Linux@CASDDS.CASD
keytab = /etc/Linux.keytab

# Configuration gMSA
gmsa_name = gMSA-hclient
gmsa_dn = CN=gMSA-hclient,CN=Managed Service Accounts,DC=casdds,DC=casd
gMSA_sAMAccountName = gMSA-hclient
gMSA_keytab = /etc/krb5.keytab

gMSA_servicePrincipalNames = host/gMSA-hclient.CASDDS.CASD,HTTP/NOM_HOST.EXEMPLE.COM,hdfs/NOM_HOST.EXEMPLE.COM

# Où écrire le keytab
target_keytab = /etc/krb5.keytab
post_renew_cmd = systemctl restart sssd.service

# Logging
log_level = INFO
```

> the ownership of  `/etc/Linux.keytab` should be gmsa:root
> the permission of `/etc/Linux.keytab` should be 640
> the ownership of  `/etc/krb5.keytab` should be root:gmsa
> the permission of `/etc/krb5.keytab` should be 640
> 
> We also need to check if the account `Linux@CASDDS.CASD` exists in AD. If existed, generate the `Linux.keytab` file.
> Don't forget to create the init `krb5.keytab` file sudo touch `/etc/krb5.keytab`.

```shell
$SamAccountName = "Linux"
$Realm          = "CASDDS.CASD"
$KeytabPath     = "C:\temp\linux.keytab"
$Crypto         = "AES256-SHA1"

$Principal = "$SamAccountName@$Realm"

# ==========================
# Generate keytab
# ==========================
ktpass `
  -princ $Principal `
  -mapuser $SamAccountName `
  -ptype KRB5_NT_PRINCIPAL `
  -crypto $Crypto `
  -pass * `
  -out $KeytabPath
```

> The above command will prompt you to enter a password, this password will replace the old password of user account AD. 
> So **all the old keytab file is no longer valid** if the password is different.

As the `gmsa account` must have the right to restart sssd, we need to add a line in sudoer

```shell
gmsa ALL=(root) NOPASSWD:systemctl restart sssd.service
```

### 2.4.4 Create a systemd service for gmsad

```ini
[Unit]
Description=gMSA daemon (gmsad)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=gmsa
Group=gmsa

Environment="VIRTUAL_ENV=/opt/gmsad_venv"
Environment="PATH=/opt/gmsad_venv/bin:/usr/bin:/bin"

# Clean old keytab safely before start
# to be discussed
# ExecStartPre=/usr/bin/rm -f /etc/krb5.keytab

ExecStart=/opt/gmsad_venv/bin/gmsad --config /etc/gmsad.conf

Restart=always
RestartSec=10
TimeoutStartSec=60

# Hardening (safe defaults)
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/etc/krb5.keytab

[Install]
WantedBy=multi-user.target

```