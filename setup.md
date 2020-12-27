# Initial setup for hosts

## Pre Ansible

If the host uses the tarsnap role, create a Tarsnap key for it
according to the README.


## Bootstrap

The following instructions have the following aim:

- Install basic OS
- Provide a `/dev/sda1` boot partition and `/dev/sda2` root partition
  each sized to about 2-4x the expected usage
- Provide an empty `/dev/sda5` partition as a site for a LUKS volume
- Protect the host from SSH login by local-network attackers using
  weak or default passwords while it is being set up, and securely
  gather the host SSH fingerprint to prevent local-network MITM attack
- Collect any host variables (partition UUIDs)
- Prepare the host for public key root login and the first Ansible run


### Bootstrap: Laptops and desktops

For laptops and desktops, use the Debian installer ISO. These
instructions were tested using the `debian-10.7.0-amd64-netinst.iso`
image on a USB stick.

Debian installer choices:

- Select whatever locale/keyboard/time zone information you want. Time
  zone will get reset to UTC during the Ansible run.
- Use the host's shortname as the host name, and leave the domain name
  empty
- Skip root password
- Put in your name and username when prompted for the regular user
  account. This account won't be used, but it should have good
  security, since the account will be sudo-capable -- choose a very
  strong passphrase.
- Manual partitioning:
    - Wipe existing partitions
    - Create 250 MB `primary` partition: ext4, mount as `/boot`, label
      `boot`, bootable flag `on`
    - Create 30 GB `primary` partition: ext4, mount as `/`, label `rootfs`
    - Create a `logical` partition in remaining space: Use as `do not use`
        - This will later be set up as the commdata LUKS/LVM partition
    - Finish partitioning; ignore warning about swap space
- On the Software Selection screen, choose only `SSH server` and
  `standard system utilities`

Reboot, and log in as the user you set up. Run `ip addr list` to
discover the local IP address.

Back on the controller, try to copy the Ansible root public key to the
home dir of the user you created. For example:

```
scp ansible/roles/common/files/id_ansible_appux.pub timmc@10.0.1.2:
```

When prompted to confirm the SSH host key, go to the new host and
print the fingerprint so you can compare it:

```
ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub
```

Once the file is transferred, SSH in to the host as your user;
remaining steps will be completed over SSH. (You can log out of the
terminal on the new host now.) Run `sudo su` and perform the
following:

```
mkdir --mode=0700 /root/.ssh
cp /home/timmc/id_ansible_appux.pub /root/.ssh/authorized_keys
chown root: /root/.ssh/authorized_keys
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
apt-get update && apt-get dist-upgrade --auto-remove
```

Finally, and still on the host, collect any necessary information for
host vars:

- Run `blkid /dev/sda5` to get the value for `commdata__luks_partuuid`
  (which is not a real UUID on an MBR partition layout)


### Bootstrap: Raspberry Pi

The Raspberry Pi setup involves modifying a fixed disk image to make
it possible to SSH into without a keyboard and monitor, but also safe
to enable SSH on. (It has a default pi/raspberry user.)

Write the disk image:

- Download latest Raspberry Pi OS (previously known as Raspbian) from
  here, preferably the Lite version: Raspberry Pi OS Lite
    - Last tested with `2020-12-02-raspios-buster-armhf-lite` on a
      Raspberry Pi 3.
- Write .img to SD card with `dd`

Set up partitions. There should already be two partitions: A small
(~200 MB) FAT partition labeled "boot" and a larger (~2 GB) ext4
partition labeled "rootfs".

In `sudo parted /dev/sdXXX`:

- `print` to confirm correct device
- Expand rootfs partition to 5 GB in size: `resizepart 2 5.2GB`
  (`5.2GB` specifies new *end location*, not size!)
- Make an extended partition in the rest of the space:
  `mkpart extended 5.2GB 100%`
- Make the encrypted partition for commdata:
  `mkpart logical 5.2GB 100%`

Now expand the rootfs filesystem into the new space:
`sudo resize2fs /dev/sdXXX2`

Mount rootfs, set `ROOTFS=<path to rootfs mount>` and
`HOSTNAME=<shortname>`, and make the following changes as root from
the base of the repo:

- Set the hostname:
  `echo "$HOSTNAME" > "$ROOTFS"/etc/hostname`
- In `"$ROOTFS"/etc/shadow` replace the `pi` user's (default) password
  hash with an asterisk so that it's safe to enable SSH. The line
  should now start `pi:*:` meaning that the password is unset.
- Configure the ansible SSH public key for root:
  `mkdir --mode=0700 "$ROOTFS"/root/.ssh; cat ansible/roles/common/files/id_ansible_appux.pub > "$ROOTFS"/root/.ssh/authorized_keys`
- Create and initialize a random seed file so first boot will have
  sufficient entropy to safely create SSH host keys:
  `dd if=/dev/urandom of="$ROOTFS"/var/lib/systemd/random-seed count=1 bs=4096; chmod u=rw,g=,o= "$ROOTFS"/var/lib/systemd/random-seed`

Now make one more change, but this time to the *boot*
partition. Create a blank file called `ssh` in the boot partition to
tell the Raspberry Pi to enable ssh on next boot.

Unmount boot and rootfs. Plug in ethernet and power, but not the
encryption key USB stick (which seems to inhibit first-boot, or at
least first-boot ssh.)

Locate the host's IP address and wait for SSH to become responsive.
(Something like `nmap -p 22 10.0.1.0/24` is great for this.)
SSH in as `root` using the Ansible root key. (You can
either trust the host fingerprints on first use or see one of the
variations below.)

As root, perform some final manual setup by running `raspi-config`:

- Accept `pi` as the default user if prompted
- Use the "Update" option to update the config tool
- "Advanced -> Memory Split" or "Performance -> GPU Memory" depending
  on model
    - Set GPU memory from 64 down to 16
- "Exit" or "Finish" and allow to reboot

Collect any necessary information for host vars:

- Run `blkid /dev/mmcblk0p5` to get the value for `commdata__luks_partuuid`
  (which is not a real UUID on this MBR partition layout)

Run `apt-get update && apt-get dist-upgrade --auto-remove` and reboot.

#### Raspberry Pi SSH non-TOFU

If you can't rely on TOFU SSH, you'll need to do one of the
following.

- Use a monitor (untested):
    1. Defer locking the `pi/raspberry` user password but proceed
       through other steps
    2. Start the Raspberry Pi *without* ethernet but with a monitor
       attached, and run `ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub`
       to discover the key fingerprints safely
    3. Complete the password locking step before attaching to ethernet
- Read the keys off the SD card:
    1. Run through the steps and allow the host to boot normally, then
       shut it down.
    2. Extract the public key fingerprints from the SD card

You could likely also generate the keys on the controller and write them to the SD card. A few wrinkles:

- There is a `regenerate_ssh_host_keys` service that will run on first
  boot and would wipe out the new keys.
- If you run `ssh-keygen -A -f "$ROOTFS"` the "comment" part of the
  public key files will contain the controller's hostname rather than
  the new host's hostname.


## Ansible run

After rebooting, insert the encryption key USB and run Ansible with
`--limit=HOSTNAME.internal`


## Post Ansible

If the host has the commdata role, copy text of
`/mnt/not-an-hsm/commdata/enckey/pass.txt` into controller's
`private-partition-passphrases.gpg` recovery file.



-------------
SCRAP

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
