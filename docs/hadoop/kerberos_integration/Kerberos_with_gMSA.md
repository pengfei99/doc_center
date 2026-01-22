# gMSA under Linux

## AD accounts

In AD, we have three different types of accounts:
- a user account
- a computer account
- a gMSA

Each account can have one or multiple SPN, but the `SPN ownership model are different`.

- Computer account:	One computer account(host) has one SPN(one host identity).
- User account:	One user account has one SPN(One service on a specific host).
- gMSA:	One gMSA account has multiple SPN(One service on multiple hosts).

## What is gMSA?

`gMSA (Group Managed Service Account)` is a service account inside AD where the AD will manage the password(e.g. password expiration, regeneration, etc.) automatically.

It provides the below features:

- password rotation(e.g. every day, every hour, etc.) automatically
- Non-interactive
- Kerberos-native
- Multiple SPNs(service principal name) for one gMSA account

> gMSA has specific rules on SPNs, for example
> 

## Debug sssd

```shell
# check config validity
sudo sssctl config-check

# check domain status
sudo sssctl domain-status casd.fr




```