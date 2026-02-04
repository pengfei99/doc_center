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
  -Path "CN=Users,DC=casdds,DC=casd"
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

### 3.4 Add spn to each gMSA account

For each gMSA account
```powershell
# the general form to add a spn to a gMSA account
# don't forget the $ at the end
setspn -S <SPN> <gMSA-account-name>

# for example
setspn -S hdfs/deb13-spark1.casdds.casd deb13-spark1$
setspn -S HTTP/deb13-spark1.casdds.casd deb13-spark1$
setspn -S host/deb13-spark1.casdds.casd deb13-spark1$

# you can check the spn existence of a gMSA account
setspn -L deb13-spark1$

# check spn registration
setspn -Q hdfs/deb13-spark1.casdds.casd

# check if a gMSA account exist
Get-ADServiceAccount -Identity deb13-spark1
```

### 3.5 Generate keytab from gMSA

We **can not** generate keytab file for the SPNs with the below command, because gMSA forbid the password modification 
by users. The password is auto managed by AD.

```powershell
# you will see error message `can't change password`
ktpass `
 /princ hdfs/deb13-spark1.casdds.casd@CASDDS.CASD `
 /mapuser deb13-spark1$@CASDDS.CASD `
 /crypto ALL `
 /ptype KRB5_NT_PRINCIPAL `
 /out hdfs_deb13-spark1.keytab `
 /pass "deb13-spark1"

```

The right way to generate the keytab file is to use a static service account to run gMSAd, or allow a Windows server 


```powershell
# get server name
$env:COMPUTERNAME

# add an user to the allow group
Add-ADGroupMember gmsa-hadoop-hosts <sAMAccountName>


```
## Debug sssd

```shell
# check config validity
sudo sssctl config-check

# check domain status
sudo sssctl domain-status casd.fr




```

## 