# Matrix

A Matrix server, using Dendrite in monolith mode with Postgres.

The homeserver is `https://matrix.appux.com` but users are
`NAME@appux.com`.

The dendrite service is compiled from source given a pinned Git commit.

## Setup

Dendrite is configured with a `server_name` of `appux.com`. That
domain is currently hosting a website, so we use the well-known hosts
mechanism to point to `matrix.appux.com` as the implementing domain
for the service. This simplifies TLS and DNS setup (versus SRV
records).

### DNS

Add record:

`matrix.appux.com CNAME t.timmc.org.`

### .well-known

Add file `https://www.appux.com/.well-known/matrix/server`:

```
{
  "m.server": "matrix.appux.com:443"
}
```
