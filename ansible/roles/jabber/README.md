# Jabber/XMPP instant messaging

Configures a Prosody server.

## Manual configuration

DNS managed at https://members.nearlyfreespeech.net/phyzome/dns/appux.com
although always just pointing to home datacenter.

To migrate to a different server, change the port forwarding on the
router instead.

Also make sure that the server you're migrating to is in the
cert-oracle's destination list and has received certs.

## Sending out a maintenance announcement

Send an IM to `appux.com/announce/online` and everyone online will
receive a message from the server.
