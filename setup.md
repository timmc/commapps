# OS

- Regular servers: Debian 10 (Buster) - stable
- Raspberry Pi: Raspbian Buster

## Raspberry Pi

### Manual bootstrap

- Write 2017-11-29-raspbian-stretch-lite.img to SD card
    - UPDATE: Get buster instead
- Connect SD card, component video, keyboard, and power
- Log in: pi/raspberry (may need to hit enter to see prompt)
- `sudo raspi-config`
    - "Change User Password"
        - Use something high-entropy (can throw it away once root SSH
          is set up)
    - "Update"
    - "Advanced" -> "Expand filesystem"
    - "Advanced" -> "Memory Split"
        - Set GPU memory from 64 down to 16
    - "Exit" (don't reboot yet)
- `sudo systemctl enable ssh`
- `sudo systemctl start ssh`
- `ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub`
    - Output: `ECDSA SHA256:0123456789ABCDEF0123456789ABCDEF0123456789A`
- Connect ethernet
- From controller machine, ssh to pi@HOSTNAME.internal and verify fingerprint
- `sudo shutdown -r now`
- Disconnect keyboard and video; everything else is over SSH
- Baseline: Use ansible playbook bootstrap.yml to bootstrap:

```
HOSTNAME=_____
USER=pi
HOSTADDR=$HOSTNAME.internal
PUBKEY=/home/timmc/.ssh/id_ansible_personal.pub
ansible-playbook bootstrap.yml --ask-pass --become --become-user=root --ask-become-pass --extra-vars="root_authkeys_path=$PUBKEY hostname=$HOSTNAME" --inventory="$HOSTADDR," --user="$USER"
```

Alternative when no video available: Touch file `ssh` on boot
partition to enable ssh, and immediately log in as pi user on ssh to
change the user's default password, then proceed with rest of config
-- including the enable/start ssh, since otherwise some systemd
symlinks aren't properly created.

## Partitioning

Partitioning example on murphy (mounted on controller):

- `fdisk -l /dev/sdb`
- `e2fsck -f /dev/sdb2`
- `resize2fs /dev/sdb2 4G` (shrink the root FS)
- `parted /dev/sdb`
    - `print`
    - `resizepart 2 5GB` (specifies new *end location*, not size)
    - `mkpart extended 5GB 100%`
    - `mkpart logical 5GB 15GB`
    - `mkpart logical 15GB 100%`
- `resize2fs /dev/sdb2` (re-expand the root FS)

Sample partitioning result from toster:

```
$ fdisk -l

Disk /dev/sda: 149.1 GiB, 160041885696 bytes, 312581808 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x453e050c

Device     Boot     Start       End   Sectors   Size Id Type
/dev/sda1  *         2048  58593279  58591232    28G 83 Linux
/dev/sda2        58595326 312580095 253984770 121.1G  5 Extended
/dev/sda5        58595328 299804671 241209344   115G 83 Linux
/dev/sda6       299806720 312580095  12773376   6.1G 83 Linux
```

## Apt sources

Regular Debian computers:

```
echo 'deb http://debian.csail.mit.edu/debian buster main contrib non-free
deb-src http://debian.csail.mit.edu/debian buster main contrib non-free

deb http://debian.csail.mit.edu/debian buster-updates main contrib non-free
deb-src http://debian.csail.mit.edu/debian buster-updates main contrib non-free

deb http://security.debian.org/ buster/updates main contrib non-free
deb-src http://security.debian.org/ buster/updates main contrib non-free
' | sudo tee /etc/apt/sources.list
```

Raspberry Pi:

```
echo 'deb http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi
deb-src http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi
' | sudo tee /etc/apt/sources.list
```

Now set up port forwarding in router and use SSH for remaining config.


# Basics
```
apt-get update
apt-get dist-upgrade
apt-get install cryptsetup git git-gui gitk nmap gnome-disk-utility
```

# For each user that needs a shell:
Set history size (can't override)
```
sed -i 's/^\(HIST\(FILE\)\?SIZE=.*\)/\10000/' ~/.bashrc
mkdir ~/dotfiles
(
cat <<'EOF'
export HISTTIMEFORMAT='%F %T '
export EDITOR="emacs -nw"
# Because Debian thinks normal users shouldn't have ifconfig or whatever
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin
EOF
) > ~/dotfiles/.bash_custom
echo 'source ~/dotfiles/.bash_custom' >> ~/.bashrc
echo 'hardstatus string "%H | %-Lw%{= BW}%50>%n* %t%{-}%+Lw%<"
defscrollback 5000
vbell off' >> ~/.screenrc
```


# Sandstorm

DNS:

```
sandy.parsni.ps CNAME k.timmc.org.
*.sandy.parsni.ps CNAME k.timmc.org.
sandstorm.appux.com CNAME t.timmc.org. 600
*.sandstorm.appux.com CNAME t.timmc.org. 600
```

Login providers:

- https://console.developers.google.com/
- https://github.com/settings/applications/248526

Run ansible scripts.

If you're restoring from backup, follow the
[standard restore instructions](https://docs.sandstorm.io/en/latest/administering/backups/):

- Stop sandstorm
- Move installed dir away, replace it with backup
- Start sandstorm

# Tarsnap

Created account `comm-tarsnap-commdata@brainonfire.net`

Install tarsnap and provision key.

Instructions for clearing old archives:

- List archives: `tarsnap --list-archives --keyfile /srv/commdata/backups/tarsnap-rw.key | sort > archives.lst`
- `cp archives.lst delete.lst` and then edit the latter
- `tarsnap -d --archive-names delete.lst --keyfile /srv/commdata/backups/tarsnap-full.passphrased.key --print-stats --humanize-numbers`
- `tarsnap --fsck`

# Prosody

DNS:

```
_xmpp-client._tcp.appux.com	SRV	10 0 5222 k.timmc.org.
_xmpp-client._tcp.muc.appux.com	SRV	10 0 5222 k.timmc.org.
_xmpp-server._tcp.appux.com	SRV	10 0 5269 k.timmc.org.
_xmpp-server._tcp.muc.appux.com	SRV	10 0 5269 k.timmc.org.
```

Create a scheduled task on `appux` NFSN site:

- Name: CertOracle
- Command: /home/private/sync/cert-oracle/update-certs.sh
- User: me
- Environment: ssh
- Hour: 6
- Day of week: Every
- Day of month: 28

Remaining setup:

- Run Ansible scripts
- When prompted, copy CSR file to cert-oracle on NFSN and run it once
- Then continue or re-run scripts

# Encrypted swap space

Reference: https://wiki.archlinux.org/index.php/Dm-crypt/Swap_encryption

Use the safest method, creating a tiny decoy filesystem and then
placing a swap space just after it using offset. This allows naming of
the swap location independent of hardware/drive order (pinning to
"/dev/sda6" could lead to data loss after repartitioning, since swapon
would overwrite a partition.)

```
mkfs.ext2 -L cryptswap /dev/sda6 1M
echo 'swap  LABEL=cryptswap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=256' >> /etc/crypttab
echo '/dev/mapper/swap  none  swap  defaults  0  0' >> /etc/fstab
```
