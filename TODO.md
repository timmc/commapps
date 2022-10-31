# TODO list

Figure out how to bring up system with SSH but without community services, perhaps by unplugging not-an-hsm.

- Control
    - Done: Move to my own domain name; prerequisites follow:
        - Done: Get wildcard cert for Sandstorm (Let's Encrypt)
        - Done: Set up nginx with reverse proxy terminating wildcard
          TLS for Sandstorm
        - Done: Wildcard DNS via NFSN
    - Done: Move from afraid.org freedns to using NFSN DNS API
- Repeatability
    - Done: Server rebuilt from (manual) runbook
    - **TODO**: Create automated runbook for post-OS setup
        - Partially complete, using Ansible
    - **TODO**: Create automated process for initial install (or
        creating an automated bootable installer)
        - Needs to handle creating partitions
        - Consider using Intel PXE, or Debian preseed
          (e.g. https://github.com/chef/bento/tree/master/debian/scripts)
- Privacy
    - Done: Sandstorm moved to encrypted partition (passphrase not on same disk)
    - Done: No other services present on rebuilt server
    - **TODO**: Set up an encrypted swap space (currently has no swap)
- Backups
    - Done: Tarsnap account set up and funded (probably will cost
      $20–100 per year)
        - Later switched to borg-backup onto BorgBase
    - Done: Script for snapshotted backups written and deployed
    - Done: Append-only key created and deployed
    - Done: cron job for automating backups
    - **TODO**: Monitoring for missed/broken backups
        - Ideally, monitor should attempt to retrieve a file from the
          most recent backup and report the age of the backup.
    - **TODO**: Perform a restore-from-backup exercise & schedule for
      quarterly execution
        - **TODO**: Monitoring on this somehow?
- Security
    - Done: Enable automatic security updates
        - **TODO**: Notifications for completed updates that require reboot
    - **TODO**: Set up monitoring for non-security updates, and
      notifications of automatically applied updates
    - **TODO**: Find and go through a Debian hardening checklist
- Availability
    - Done: Set up monitoring: Uptime
    - **TODO**: More advanced monitoring (running out of disk, high
      memory usage, log errors...)
    - **TODO**: Set up monitoring: SSL cert expiration
