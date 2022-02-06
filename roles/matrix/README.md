# Matrix

A Matrix server, using Dendrite in monolith mode with Postgres.

The homeserver is `https://matrix.appux.com` but users are
`NAME@appux.com`.

The dendrite service is compiled from source given a pinned Git commit.

The role must be run with a `matrix__cfg` object containing the bulk
of the config; this allows for a staging and a production environment
to be defined in vars rather than the runbook. (In my case,
`m.staging.appux.com` and `matrix.appux.com`.)

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

## Reset a user password

If someone forgets their password, a new password can be generated for
the database like so:

```
htpasswd -nBC10 "" | sed 's/^:\$2y\$/$2a$/'
```

And then in the DB (`sudo -u postgres psql`):

```
\c dendrite
update account_accounts set password_hash = '$2a$10$...' where localpart = '...';
```

## Registration UI

Administration is performed as the `matreg` user from its home directory.

### First-time setup

On the server, generate a token for users:

`./venv/bin/matrix-registration --config-path config.yaml generate`

This will output a token made of several dictionary words.

(FIXME: In v0.9.1 and current master branch, there is a bug in the
`POST /api/token` code, so we can't use the `admin.sh` script here.)

### Giving out a registration link

A URL like this can now be given to people to allow registration:

`https://matrix.appux.com/regui/register?token=GENERATED_TOKEN`

### If a token is compromised

Disable the old token:

`./admin.sh /api/token/OLD_TOKEN_NAME -X PATCH -d '{"disabled": true}'`

Then generate a new one, as in the first-time setup.

## TODO

- Remove old naffka DB tables from pre-0.6 dendrite?
