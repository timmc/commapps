# OS

- Regular servers: Debian 9 (Stretch) - stable
- Raspberry Pi: Raspbian Stretch

## Raspberry Pi

### Manual bootstrap

- Write 2017-11-29-raspbian-stretch-lite.img to SD card
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

# Partitioning

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

# Apt sources

```
echo 'deb http://debian.csail.mit.edu/debian jessie main contrib non-free
deb-src http://debian.csail.mit.edu/debian jessie main contrib non-free

deb http://debian.csail.mit.edu/debian jessie-updates main contrib non-free
deb-src http://debian.csail.mit.edu/debian jessie-updates main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main contrib non-free
' | sudo tee /etc/apt/sources.list
```

Now set up port forwarding in router and use SSH for remaining config.


# Basics
```
timedatectl set-timezone Etc/UTC
apt-get update
apt-get dist-upgrade
apt-get install cryptsetup git git-gui gitk nmap gnome-disk-utility
```


# Custom utilities

These will be used for backups, mounting, and other maintenance and
administration.

`mkdir /opt/commapps && git clone https://github.com/timmc/commapps.git /opt/commapps/repo`


# For each user:
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

# Additional repos:

For ZFS, among others:

```
echo 'deb http://debian.csail.mit.edu/debian/ jessie-backports main contrib' >> /etc/apt/sources.list.d/backports.list
apt-get update
```


# Encrypted, snapshottable partition for community data
apt-get install -t jessie-backports zfs-dkms

## Make LUKS-encrypted partition
```
cryptsetup --key-file /mnt/not-an-hsm/commdata/enckey/pass.txt luksFormat /dev/sda5
cryptsetup --key-file /mnt/not-an-hsm/commdata/enckey/pass.txt open /dev/sda5 con-commdata --type luks
```

## Create ZFS pool with manual mounting
```
# TODO: set canmount=noauto ?
zpool create -m legacy commdata /dev/mapper/con-commdata
mount -t zfs /dev/mapper/con-commdata /srv/commdata
```

# Sandstorm

```
wget https://raw.githubusercontent.com/sandstorm-io/sandstorm/master/install.sh
bash install.sh
```

Choose a developer install and set these options:

- Don't expose only to localhost
- Install into `/srv/commdata/sandstorm`
- Accept the `sandstorm` user but don't add own account to that group
- Do start sandstorm at startup

If you're restoring from backup, the other options don't matter, since
you'll then follow the
[restore](https://docs.sandstorm.io/en/latest/administering/backups/)
instructions:

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
