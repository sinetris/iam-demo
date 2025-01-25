# midPoint

## Configuration

Convert certificate to `der`:

```sh
openssl x509 -outform der -in cacert.crt -out cacert.der
```

### Keystore

Add certificate to keystore:

```sh
keytool -keystore keystore.jceks \
  -storetype jceks \
  -storepass changeit \
  -import \
  -alias evolveum \
  -trustcacerts \
  -file cacert.der
```
