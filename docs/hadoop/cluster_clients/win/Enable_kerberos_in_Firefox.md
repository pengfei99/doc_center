# automatic kerberos authentication in Firefox

To enable automatic kerberos authentication in Firefox, you can follow the below steps:

## 1. Access the firefox configuration page

Open your Firefox on the client computer, type `about:config` in the address field.

## 2. Check the krb authentication config
In the search bar, type `network.negotiate`, you should find config parameters such as
- `network.negotiate-auth.trusted-uris`
- `network.negotiate-auth.delegation-uris` 

The below figure shows an example:
![firefox_krb_auth_config.png](../../../assets/firefox_krb_auth_config.png)

## 3. setup uris

The most important attributes are `network.negotiate-auth.trusted-uris` and `network.negotiate-auth.delegation-uris` 
you should enter the hostname(e.g. nn.casd.fr, dn1.casd.fr) of the on-premises gateway, and then click OK.


> You can type the hostnames of several on-premises gateways, separating them with commas. 
> To include all the on-premises gateways that support Kerberos authentication in the AD domain, 
> type the AD domain name starting with a dot, for example, `.casd.fr`.
> 
> 