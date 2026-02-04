# Use gmsad to sync keytab of gMSA account

`gmsad manages Active Directory group Managed Service Account (gMSA) on Linux`.

To make it work, it requires:
- an account which has the ability to retrieve the secret of a gMSA and its credential(.keytab)
- ldaps protocol enabled and AD certificate
- target gMSA spn, name, etc.

Once configured correctly, gmsad creates a `keytab` of the target gMSA and renew it when necessary. 
> It can execute an arbitrary command just after renewing the keytab.

You can find the project github page [here](https://github.com/cea-sec/gmsad/tree/main), and the projet PYPI [here](https://pypi.org/project/gmsad/)

## 0. Pre-requis

We suppose you have already created gMSA accounts and the user account for retrieving gMSA accounts keytab

```powershell
# create a scurity group under CN=Users,DC=casdds,DC=casd in AD
New-ADGroup `
  -Name "gmsa-hadoop-hosts" `
  -GroupScope Global `
  -Path "CN=Users,DC=casdds,DC=casd"

# check if user exist with it's principal name
Get-ADUser -Filter 'UserPrincipalName -eq "Linux@casdds.casd"'

# add a user to a group in general form
Add-ADGroupMember gmsa-hadoop-hosts <sAMAccountName>

# for example
Add-ADGroupMember gmsa-hadoop-hosts Linux

# create a gMSA account allow security group to retrive password
New-ADServiceAccount `
  -Name "deb13-spark1" `
  -DNSHostName "deb13-spark1.casdds.casd" `
  -PrincipalsAllowedToRetrieveManagedPassword "gmsa-hadoop-hosts" `
  -KerberosEncryptionType AES256,AES128

```

After the above commands, user `Linux` should have the right to retrieve gMSA accounts keytab 

You can use the below script to get the `Linux` user account keytab. Note that, each time it will change the password 
of the account, and old `.keytab` is no longer valid.

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
> The above command will prompt you to enter a password, this password will replace the old password of user account in AD. 
> So **all the old keytab file is no longer valid** if the password is different.

## 1 Create local account to run gMSAd

It's recommended to run the gMSA daemon with a specific service account under linux

```shell
# create group
addgroup --system gmsa

# create service account
adduser --system --no-create-home --shell=/usr/sbin/nologin --ingroup=gmsa gmsa

```

## 2 Install the gMSA binary

```shell
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
## 3 Configure gMSAd

The main configuration file of gMSAd is located at `/etc/gmsad.conf`. If you have multiple .keytab to manage, it's 
recommended to store them in a single folder `/etc/security/keytabs/`

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
keytab = /etc/security/keytabs/Linux.keytab

# Configuration gMSA
gmsa_name = deb13-spark1
gmsa_dn = CN=deb13-spark1,CN=Managed Service Accounts,DC=casdds,DC=casd
gMSA_sAMAccountName = deb13-spark1$
gMSA_keytab = /etc/security/keytabs/deb13-spark1.keytab

gMSA_servicePrincipalNames = host/deb13-spark1.casdds.casd,HTTP/deb13-spark1.casdds.casd,hdfs/deb13-spark1.casdds.casd

# Où écrire le keytab
target_keytab = /etc/security/keytabs/deb13-spark1.keytab
post_renew_cmd = systemctl restart sssd.service

# Logging
log_level = INFO

```

> the ownership of  `/etc/security/keytabs/Linux.keytab` should be gmsa:root
> the permission of `/etc/security/keytabs/Linux.keytab` should be 640
> the ownership of  `/etc/security/keytabs/deb13-spark1.keytab` should be root:gmsa
> the permission of `/etc/security/keytabs/deb13-spark1.keytab` should be 660
> 


As the `gmsa account` must have the right to restart sssd, we need to add a line in sudoer

```shell
gmsa ALL=(root) NOPASSWD:systemctl restart sssd.service
```

> Don't forget gMSA_sAMAccountName always has a `$` sign at the end(e.g. deb13-spark1$). Because it's a gMSA account 

## 4. Add certificate to enable Ldaps

You can notice that gmsad uses LDAPs protocol, if the certificate is not signed by a valid CA, you need to add the
custom CA certificate to your local server. Below is an example of how to.

```shell
# copy root ca of ad to the local server
mv root-ca.crt /usr/local/share/ca-certificates/.

# ask debian to load the new certificate
sudo update-ca-certificates
```

## 5. Test your config
```powershell
# activate
source /opt/gmsad/gmsad-venv/bin/activate

# start the gmsad 
gmsad --config /etc/gmsad.conf

# if everything works well, you should see the below output
INFO:root:Log level is set to INFO
INFO:root:Keytab file is empty.
INFO:root:Retrieving secret of deb13-spark1$
INFO:root:Keytab entries for SPN host/deb13-spark1.casdds.casd@CASDDS.CASD have been updated successfully (kvno = 1). Next update on 2026-03-05T06:55:00+01:00
INFO:root:Keytab entries for SPN HTTP/deb13-spark1.casdds.casd@CASDDS.CASD have been updated successfully (kvno = 1). Next update on 2026-03-05T06:55:00+01:00
INFO:root:Keytab entries for SPN hdfs/deb13-spark1.casdds.casd@CASDDS.CASD have been updated successfully (kvno = 1). Next update on 2026-03-05T06:55:00+01:00

# check the generated keytab files
klist -k /etc/security/keytabs/deb13-spark1.keytab

# expected output
Keytab name: FILE:/etc/security/keytabs/deb13-spark1.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   1 host/deb13-spark1.casdds.casd@CASDDS.CASD
   1 host/deb13-spark1.casdds.casd@CASDDS.CASD
   1 HTTP/deb13-spark1.casdds.casd@CASDDS.CASD
   1 HTTP/deb13-spark1.casdds.casd@CASDDS.CASD
   1 hdfs/deb13-spark1.casdds.casd@CASDDS.CASD
   1 hdfs/deb13-spark1.casdds.casd@CASDDS.CASD

# simulate a service authentication
kinit -k -t /etc/security/keytabs/deb13-spark1.keytab host/deb13-spark1.casdds.casd@CASDDS.CASD
klist -f -e
```
## 6. Create a systemd service for gmsad

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
