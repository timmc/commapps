# Sandstorm

## Initial setup

DNS:

```
sandstorm.appux.com CNAME t.timmc.org. 600
*.sandstorm.appux.com CNAME t.timmc.org. 600
```

Login providers:

- https://console.developers.google.com/
- https://github.com/settings/applications/248526

## Restoring from backup

If you're restoring from backup, follow the
[standard restore instructions](https://docs.sandstorm.io/en/latest/administering/backups/):

- Stop sandstorm
- Move installed dir away, replace it with backup
- Start sandstorm
