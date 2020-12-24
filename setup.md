# Initial setup for hosts

## Installation and partitioning

### Laptops and desktops

For laptops and desktops, use the Debian netinst installer.

TODO: Rewrite instructions

### Raspberry Pi

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
`HOSTNAME=<shortname>`, and make the following changes as root:

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

Unmount boot and rootfs. Plug in ethernet and power, find the IP
address (e.g. `nmap -p 22 10.0.1.0/24`), and wait until SSH is
responsive. SSH in as `root` using the Ansible root key. (You can
either trust the host fingerprints on first use or see one of the
variations below.)

As root, perform some final manual setup by running `raspi-config`:

- Accept `pi` as the default user if prompted
- Use the "Update" option
- "Advanced -> Memory Split" or "Performance -> GPU Memory"
    - Set GPU memory from 64 down to 16
- "Exit" or "Finish" and allow to reboot

Collect any necessary information for host vars:

- Run `blkid /dev/mmcblk0p5` to get the encrypted partition PARTUUID
  (which is not a real UUID on this MBR partition layout)

Run `apt-get update && apt-get dist-upgrade --auto-remove` and reboot.

Insert the encryption key USB and proceed to running Ansible.

#### Variations

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


# To incorporate




## Partitioning

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

# Pre Ansible

If the host uses the tarsnap role, create a Tarsnap key for it
according to the README.

# Post Ansible

If the host has the commdata role, copy text of
`/mnt/not-an-hsm/commdata/enckey/pass.txt` into controller's
`private-partition-passphrases.gpg` recovery file.
