# AD KDC kerberos ticket debugging

There are different type of kerberos ticket:
- tkt
- service ticket

## 1 KDC general steps when a user asks a Service ticket

When user asks a service ticket to a specific service, the KDC checks:
1. service principal exists
2. The user `Alice` is a valid user (if `Alice` has a TKT)
3. realm policy allows ticket issuance

## 2. Check if service principal exists

## 3. Check if user has TKT

## 4. how to check realm policy allows ticket issuance in AD

In Active Directory there isn’t a single check called `realm allows tickets`. Ticket issuance is controlled by a 
combination
- Kerberos policy
- account restrictions
- encryption compatibility. 

You need to verify all three layers to make sure if a user has the right to have the service ticket. Below is the 
practical checklist for admins use:
1. Check domain Kerberos policy
2. Check user account is allowed Kerberos logon 
3. Check service account allows Kerberos

### 4.1 Check domain Kerberos policy

Below are some commands which can help you to get global ticket behavior.
```powershell
# On a domain controller, get default password policy:
Get-ADDefaultDomainPasswordPolicy

# generate a GPO report in html format:
Get-GPOReport -All -ReportType Html -Path report.html
```

Open the report and look for:

```text
Computer Configuration
 → Windows Settings
   → Security Settings
     → Account Policies
       → Kerberos Policy

```


Key fields to check:
- Maximum lifetime for service ticket 
- Maximum lifetime for user ticket 
- Maximum lifetime for ticket renewal 
- Maximum tolerance for clock sync

> If these values exist and are not zero or disabled, the realm is issuing tickets normally.
> A broken Kerberos realm usually shows extreme or corrupt values.

### 4.2 Check if user account is allowed Kerberos logon

```powershell
# check properties of a user account
Get-ADUser <user-name> -Properties *

# for example to get alice user properties
Get-ADUser alice -Properties *

# to check if ticket issuance is allowed
Get-ADUser alice -Properties userAccountControl | Select Name,Enabled
# if the output is `Enabled = True`, the ticket issuance is allowed.
```
You need to pay extra attentions on the below properties:
- UserAccountControl 
- AccountExpirationDate 
- SmartcardLogonRequired

Some common red flags:
- account disabled
- expired
- logon restrictions 
- `Do not require Kerberos preauthentication` misused
- smartcard-only enforcement




### 4.3 Check service account (gMSA) allows Kerberos

```powershell
# get gmsa account properties
Get-ADServiceAccount <gmsa-account-name> -Properties *
```
Check the below properties
- KerberosEncryptionType: It must include AES(e.g. AES256, AES128). If encryption types mismatch Linux settings, ticket issuance fails silently.
- ServicePrincipalNames


### 4.4 Check SPN registration

The service ticket contains a SPN which the user wants to access with the ticket. If SPN is missing or duplicated, 
KDC refuses ticket:

```powershell
# check spn registration
setspn -Q nn/namenode.example.com

# Expected output
Registered to gmsa-hdfs-nn$
```
> Missing or duplicates break Kerberos ticket generation.

### 4.5. Check domain functional level
Kerberos features depend on domain mode. Old domain modes may block the encryption types
```powershell
# get ad domain mode
Get-ADDomain | Select DomainMode
```
> If the domain mode is > modern (2012+), then it is fine.


## 5. Generate a ticket 

The definitive check is requesting one ticket which the user needs.
```powershell
# get all ticket
kinit alice
# 
kvno nn/namenode.example.com

```
If this succeeds, it means:
- realm policy allows ticket issuance 
- SPN valid 
- encryption compatible 
- account permitted

## 6. Check DC event logs

If you have unkonw problems, you can check the dc event logs.

On domain controller:
```powershell
Event Viewer
 → Windows Logs
   → Security
```

Kerberos failures appear as:
- Event ID 4768  (TGT request)
- Event ID 4769  (service ticket request)


Failure codes show exactly why a ticket was denied. Below are some common failure code example:

- KDC_ERR_CLIENT_REVOKED 
- KDC_ERR_S_PRINCIPAL_UNKNOWN 
- KDC_ERR_ETYPE_NOTSUPP


> In AD, ticket issuance is the default behavior. It is denied only if:
> - account invalid 
> - SPN broken 
> - encryption mismatch 
> - clock skew 
> - DC replication failure 
> There is no global “block service ticket” toggle. Kerberos is permissive by design.