# AD KDC kerberos ticket debugging

There are different type of kerberos ticket:
- tkt
- service ticket

## what KDC do when a user ask a Service ticket

When user ask a service ticket to a specific service, the KDC checks:
- service principal exists
- `Alice` is a valid user (if `Alice` has a TKT)
- realm policy allows ticket issuance

### Check if service principal exists
### Check if user has TKT
### how to check realm policy allows ticket issuance in AD

In Active Directory there isn’t a single check called `realm allows tickets`. Ticket issuance is controlled by a 
combination
- Kerberos policy
- account restrictions
- encryption compatibility. 

You need to verify all three layers to make sure if a user has the right to have the service ticket. Below is the 
practical checklist for admins use:
1. Check domain Kerberos policy

This defines global ticket behavior.
```powershell
# On a domain controller:

Get-ADDefaultDomainPasswordPolicy

# Then:

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


Key fields:

Maximum lifetime for service ticket

Maximum lifetime for user ticket

Maximum lifetime for ticket renewal

Maximum tolerance for clock sync

If these values exist and are not zero or disabled, the realm is issuing tickets normally.

A broken Kerberos realm usually shows extreme or corrupt values.

2. Check user account is allowed Kerberos logon

For Alice:

Get-ADUser alice -Properties *


Look at:

UserAccountControl
AccountExpirationDate
SmartcardLogonRequired


Red flags:

account disabled

expired

logon restrictions

“Do not require Kerberos preauthentication” misused

smartcard-only enforcement

Quick readable view:

Get-ADUser alice -Properties userAccountControl |
Select Name,Enabled


If Enabled = True, ticket issuance is allowed.

3. Check service account allows Kerberos

For the gMSA:

Get-ADServiceAccount gmsa-hdfs-nn -Properties *


Look at:

KerberosEncryptionType
ServicePrincipalNames


Must include AES:

AES256
AES128


If encryption types mismatch Linux settings, ticket issuance fails silently.

4. Check SPN registration

If SPN is missing or duplicated, KDC refuses ticket:

setspn -Q nn/namenode.example.com


Expected:

Registered to gmsa-hdfs-nn$


Duplicates break Kerberos.

5. Check domain functional level

Kerberos features depend on it:

Get-ADDomain | Select DomainMode


Anything modern (2012+) is fine.

Ancient domain modes can block encryption types.

6. Real test: ask for a ticket

The definitive check is requesting one.

From a Kerberos client:

kinit alice
kvno nn/namenode.example.com


If this succeeds:

→ realm policy allows ticket issuance
→ SPN valid
→ encryption compatible
→ account permitted

This test is more reliable than reading policies.

7. Check DC event logs

On domain controller:

Event Viewer
 → Windows Logs
   → Security


Kerberos failures appear as:

Event ID 4768  (TGT request)
Event ID 4769  (service ticket request)


Failure codes show exactly why a ticket was denied.

Example:

KDC_ERR_CLIENT_REVOKED
KDC_ERR_S_PRINCIPAL_UNKNOWN
KDC_ERR_ETYPE_NOTSUPP


These map directly to configuration problems.

Key insight

In AD, ticket issuance is the default behavior.

It is denied only if:

account invalid

SPN broken

encryption mismatch

clock skew

DC replication failure

There is no global “block service ticket” toggle.

Kerberos is permissive by design.