# Simple ansible role to install and maintain the Bind9 nameserver

This role installs and configures the Bind9 nameserver on Ubuntu.

## Basic server configuration

### Primary server

* set vars for your primary server, for instance in `host_vars/primary_name/vars/XX_bind.yml`, here with an example.com static zones and forwarder:

```yaml
bind9_authoritative: true
bind9_admin_email: hostmaster@example.org
bind9_forwarder: true
bind9_forwarders:
  - 1.1.1.1
  - 8.8.8.8
bind9_zones:
  - name: example.org
    ttl: 1d
    refresh: 3h
    retry: 15m
    expire: 1d
    minimum: 2h
    ns_records:
      - ns1.dns-server.test.
      - ns2.other-dns-server.test.
    a_records:
      - 192.168.0.1
    aaaa_records:
      - fc00::
    mx_records:
      - priority: 10
        name: mx1.example.org.
    caa_records: 
      - 0 issue "example-ca.org"
    resource_records:
      - label: www
        ttl: 1h
        type: A
        content: 192.168.0.1
      - label: ftp
        ttl: 2h
        type: CNAME
        content: www
      - label: something
        ttl: 2h
        type: CNAME
        content: external.example.com.
      - label: subdomain
        ttl: 30m # see TTL section for examples
        type: A|CNAME|TXT|...
        content: IP|other-subdomain|fqdn-ending-with-dot|etc
```

### Zone file

#### Zone file example

```zone
; base zone file for example.com
$TTL 2d    ; default TTL for zone
$ORIGIN example.com.

; Start of Authority Resource Record (RR) defining the key characteristics of
; the zone (domain)
@         IN      SOA   ns1.example.com. hostmaster.example.com. (
                                1694626163 ; serial number (must be between 1 and 4294967295)
                                12h        ; refresh
                                15m        ; update retry
                                3w         ; expiry
                                2h         ; minimum
                                )
; name server RR for the domain
           IN      NS      ns1.example.com.
; the second name server is external to this zone (domain)
           IN      NS      ns2.example.net.
; mail server RRs for the zone (domain)
        3w IN      MX  10  mail.example.com.
; the second  mail servers is external to the zone (domain)
           IN      MX  20  mail.example.net.
; domain hosts includes NS and MX records defined above
; plus any others resource record we require
; for instance a user query for the A RR of joe.example.com will
; return the IPv4 address 192.168.254.6 from this zone file
ns1        IN      A       192.168.254.2
mail       IN      A       192.168.254.4
joe        IN      A       192.168.254.6
www        IN      A       192.168.254.7
; aliases ftp (ftp server) to an external domain
ftp        IN      CNAME   ftp.example.net.
```

#### TTL format

TTL is represented in seconds, but in BIND you can also use time unit
abbreviations.

| abbreviation | unit    | description        |
| :----------: | ------- | ------------------ |
|      s       | seconds | # x 1 seconds      |
|      m       | minutes | # x 60 seconds     |
|      h       | hours   | # x 3600 seconds   |
|      d       | day     | # x 86400 seconds  |
|      w       | week    | # x 604800 seconds |

You can find some examples for valid TTL values in the following table.

|    value |                       description | value in seconds |
| -------: | --------------------------------: | :--------------: |
|      30s |                        30 seconds |        30        |
|       5m |                         5 minutes |       300        |
|     100m |                       100 minutes |       6000       |
|       4h |                           4 hours |      14400       |
|      48h |                          48 hours |      172800      |
|       7d |                            7 days |      604800      |
|       2w |                           2 weeks |     1209600      |
|    2h30m |            2 hours and 30 minutes |       9000       |
| 4h15m30s | 4 hours 15 minutes and 30 seconds |      15330       |
|     2d4h |                2 days and 4 hours |      187200      |

**Note:** The maximum TTL value is usually capped at 7 days.

## TODO

```sh
sudo resolvectl dns ens3 192.168.105.62
sudo resolvectl domain ens3 iam-demo.test

```
