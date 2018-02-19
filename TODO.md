# TODO list

- Control
    - **TODO**: Move to my own domain name; prerequisites follow:
        - Done: Buy wildcard cert
          ([$40–70/yr](https://www.ssl2buy.com/wildcard-ssl-certificate/))
        - Set up nginx with reverse proxy terminating wildcard TLS for
          Sandstorm
        - **TODO**: Set up or find DNS server (might use afraid.org at first)
- Repeatability
    - Done: Server rebuilt from (manual) runbook
- Privacy
    - Done: Sandstorm moved to encrypted partition (passphrase not on same disk)
    - Done: No other services present on rebuilt server
    - **TODO**: Set up an encrypted swap space (currently has no swap)
- Backups
    - Done: Tarsnap account set up and funded (probably will cost
      $20–100 per year)
    - Done: Script for snapshotted backups written and deployed
    - Done: Append-only key created and deployed
    - Done: cron job for automating backups
    - **TODO**: Monitoring for missed/broken backups
        - Ideally, monitor should attempt to retrieve a file from the
          most recent backup and report the age of the backup.
    - **TODO**: Monitoring for lingering ZFS snapshots
    - **TODO**: Schedule and perform a restore-from-backup exercise
- Security
    - **TODO**: Enable automatic security updates
    - **TODO**: Set up monitoring for non-security updates, and
      notifications of automatically applied updates
    - **TODO**: Find and go through a Debian hardening checklist
- Availability
    - **TODO**: Set up monitoring: Uptime
    - **TODO**: Set up monitoring: SSL cert expiration
