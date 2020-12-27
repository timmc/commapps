# Jabber/XMPP instant messaging

Configures a Prosody server.

## Setting up a new server

- Add to role vars
- Add a vhost configuration
- Add to `secure_domains` in main Prosody config
- Follow manual configuration instructions below

## Manual configuration

Remember to follow these instructions for all domains hosted at appux,
not just `appux.com`. See role vars for list.

### DNS

DNS managed at https://members.nearlyfreespeech.net/phyzome/dns/appux.com
although always just pointing to home datacenter.

To migrate to a different server, change the port forwarding on the
router instead.

DNS:

```
_xmpp-client._tcp.appux.com	SRV	10 0 5222 t.timmc.org.
_xmpp-client._tcp.muc.appux.com	SRV	10 0 5222 t.timmc.org.
_xmpp-server._tcp.appux.com	SRV	10 0 5269 t.timmc.org.
_xmpp-server._tcp.muc.appux.com	SRV	10 0 5269 t.timmc.org.
```

### Cert oracle

TLS certificates are produced by a cron job called the "cert-oracle"
on the corresponding web servers for each domain name.

The jabber host generates a TLS key and a certificate signing request
(CSR). During the initial Ansible run, you'll be prompted to copy the
CSR file to the cert-oracle on NFSN and run it once. This will
generate a TLS certificate and place it in apublic place. (Neither
certificates nor CSRs are sensitive, but the key must be kept
private.) Continue the Ansible run once you've done so.

You'll also need to create a scheduled task on each NFSN site:

- Name: CertOracle
- Command: /home/private/sync/cert-oracle/update-certs.sh
- User: me
- Environment: ssh
- Hour: 6
- Day of week: Every
- Day of month: 28

This will take care of periodically regenerating the certificate, and
the jabber host will download the certificate every few days.

## Sending out a maintenance announcement

Send an IM to `appux.com/announce/online` and everyone online will
receive a message from the server.
