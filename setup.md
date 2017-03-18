# OS

Debian 8 (Jessie) - stable

# Partitioning

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


# With physical access

Set up `/home/timmc/.ssh/authorized_keys` and record fingerprint of
`ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub`. Note the LAN IP
address as well.

## Get wifi working

```
echo 'deb http://debian.csail.mit.edu/debian jessie main contrib non-free
deb-src http://debian.csail.mit.edu/debian jessie main contrib non-free

deb http://debian.csail.mit.edu/debian jessie-updates main contrib non-free
deb-src http://debian.csail.mit.edu/debian jessie-updates main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main contrib non-free
' | sudo tee /etc/apt/sources.list
apt-get update
apt-get install firmware-iwlwifi
modprobe -r iwlwifi
modprobe iwlwifi
```

Now set up port forwarding in router and use SSH for remaining config.


# Basics
```
timedatectl set-timezone Etc/UTC
apt-get update
apt-get dist-upgrade
apt-get install ssh emacs screen curl cryptsetup git git-gui gitk nmap gnome-disk-utility
```


# Custom utilities

These will be used for backups, mounting, and other maintenance and
administration.

`mkdir /opt/commapps && git clone https://github.com/timmc/commapps-utils.git /opt/commapps/utils`


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


# As laptop
`apt-get install x11vnc xtightvncviewer`

Prevent logind from suspending laptop when lid-close w/o desktop sesssion:

`echo 'HandleLidSwitch=ignore' >> /etc/systemd/logind.conf`


# Secrets store

A meh place to store secrets like encryption passphrases required for
startup:

```
mkdir /mnt/not-an-hsm
echo 'UUID=c04b9188-0f23-4c85-b18b-718e6a631703 /mnt/not-an-hsm ext4 defaults 0 2' >> /etc/fstab
mount -a
```


# Additional repos:

For ZFS, among others:

```
echo 'deb http://debian.csail.mit.edu/debian/ jessie-backports main contrib' >> /etc/apt/sources.list.d/backports.list
apt-get update
```


# Encrypted, snapshottable partition for community data
apt-get install -t jessie-backports zfs-dkms

## Set up passphrase file
mkdir -p /mnt/not-an-hsm/commdata/enckey/
chown root:root /mnt/not-an-hsm/commdata/enckey/
chmod 700 /mnt/not-an-hsm/commdata/enckey/
tr -d '\r\n' > /mnt/not-an-hsm/commdata/enckey/pass.txt

## Make LUKS-encrypted partition
```
cryptsetup --key-file /mnt/not-an-hsm/commdata/enckey/pass.txt luksFormat /dev/sda5
cryptsetup --key-file /mnt/not-an-hsm/commdata/enckey/pass.txt open /dev/sda5 con-commdata --type luks
```

## Create ZFS pool with manual mounting
```
mkdir /opt/commdata
# TODO: set canmount=noauto ?
zpool create -m legacy commdata /dev/mapper/con-commdata
mount -t zfs /dev/mapper/con-commdata /opt/commdata
```

## Install startup service

We have systemd v215, but need at least v228 (?) in order to enable a
symlinked unit file: https://github.com/systemd/systemd/issues/1836

```
cp /opt/commapps/utils/scripts/encfs/systemd-service /etc/systemd/system/commapps.service
systemctl enable commapps.service
```


# Sandstorm

```
wget https://raw.githubusercontent.com/sandstorm-io/sandstorm/master/install.sh
bash install.sh
```

Choose a developer install and set these options:

- Don't expose only to localhost
- Install into `/opt/commdata/sandstorm`
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

## Install Tarsnap

wget https://pkg.tarsnap.com/tarsnap-deb-packaging-key.asc
apt-key add tarsnap-deb-packaging-key.asc
echo 'deb http://pkg.tarsnap.com/deb/jessie ./' > /etc/apt/sources.list.d/tarsnap.list
apt-get update
apt-get install tarsnap

## Configure key

Create a write-only key and save the full key somewhere else.

```
mkdir /opt/commdata/backups
tarsnap-keygen --keyfile /opt/commdata/backups/tarsnap-full.key --user comm-tarsnap-commdata@brainonfire.net --machine toster
tarsnap-keymgmt --outkeyfile /opt/commdata/backups/tarsnap-w.key -w /opt/commdata/backups/tarsnap-full.key
less /opt/commdata/backups/tarsnap-full.key # save this off somewhere...
shred /opt/commdata/backups/tarsnap-full.key
```

## Automate
```
ln -ns /opt/commapps/utils/scripts/backup/cron /etc/cron.d/commdata-backup
```


# Encrypted swap space

**TODO**, and stay the hell away from crypttab unless you use the
tiny-fs UUID trick.


