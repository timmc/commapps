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
cp /opt/commapps/repo/scripts/encfs/systemd-service /etc/systemd/system/commapps.service
systemctl daemon-reload
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

Create a full key, generate read/write-only and full (but
passphrase-protected) variants, save off the full key, and shred
it. Passphrase is stored in `tarsnap-full.passphrase.gpg` on
management machine; full key stored in `tarsnap-full.key.gpg`.

Full key is used for periodic deletions of old archives. Read/write
key cannot be used to delete archives (if an attacker gets into the
machine and wants to wipe it) but can be used to --fsck.

**TODO**: Automate fsck after archive deletion/rotation (will need to
be done every time an archive is deleted using a different cache dir);
alternatively, push cache dir to host after deletions.

```
mkdir /opt/commdata/backups
pushd /opt/commdata/backups
tarsnap-keygen --keyfile tarsnap-full.key --user comm-tarsnap-commdata@brainonfire.net --machine toster
tarsnap-keymgmt --outkeyfile tarsnap-rw.key -r -w tarsnap-full.key
tarsnap-keymgmt --outkeyfile tarsnap-full.passphrased.key --passphrased -r -w -d --nuke tarsnap-full.key
less tarsnap-full.key # save this off somewhere...
shred tarsnap-full.key
popd
```

## Automate
```
ln -ns /opt/commapps/repo/scripts/backup/cron /etc/cron.d/commdata-backup
```


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
