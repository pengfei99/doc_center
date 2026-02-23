
To enable automatic authentication in Firefox:
- Open Firefox on a client computer and type "about:config" in the address field.
- Locate `network.negotiate-auth.trusted-uris` and double-click it.
- On the screen that appears, type the hostname of the on-premises gateway, and then click OK.
- You can type the hostnames of several on-premises gateways, separating them with commas. To include all the on-premises gateways that support Kerberos authentication in the AD domain, type the AD domain name starting with a dot, for example, .example.com.