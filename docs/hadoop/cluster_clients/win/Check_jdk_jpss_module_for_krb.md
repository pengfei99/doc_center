# Check JDK jpss module

In windows, hadoop uses jdk jpss module do read the kerberos ticket cache from the LSA.

```shell
java --list-modules | findstr java.security.jgss

# expected output for jdk 11.
java.security.jgss@11.0.3
```