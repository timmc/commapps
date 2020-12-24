# Jabber/XMPP instant messaging

Configures a Prosody server.

## Manual configuration

Remember to follow these instructions for all domains hosted at appux,
not just `appux.com`.

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

TLS certificates are delivered by a cron job called the "cert-oracle"
on the web server that hosts `https://appux.com`.

Make sure that the server you're migrating to is in the cert-oracle's
destination list and has received certs.

Create a scheduled task on `appux` NFSN site:

- Name: CertOracle
- Command: /home/private/sync/cert-oracle/update-certs.sh
- User: me
- Environment: ssh
- Hour: 6
- Day of week: Every
- Day of month: 28

During the initial Ansible run, you'll be prompted to copy the CSR
file to the cert-oracle on NFSN and run it once. Do so, then continue
or re-run the Ansible scripts.

## Sending out a maintenance announcement

Send an IM to `appux.com/announce/online` and everyone online will
receive a message from the server.
