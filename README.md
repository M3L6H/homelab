<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [homelab](#homelab)
  - [initial setup](#initial-setup)
    - [Configure networking](#configure-networking)
    - [Set up bootloader (optional)](#set-up-bootloader-optional)
  - [NVMe](#nvme)
    - [troubleshooting](#troubleshooting)
  - [ssh-keys](#ssh-keys)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# homelab

Notes on setting up my homelab.

## initial setup

Begin by inserting the microSD card for the Raspberry Pi.

Identify the device by running:

```sh
lsblk
```

Run rpi-imager with:

```sh
# -E is needed because rpi-imager doesn't have access to the display otherwise
nohup sudo -E rpi-imager >script.log 2>&1 &
```

Follow the instructions in rpi-imager.

After flashing the drive, insert it into the Raspberry Pi & power on the Raspberry Pi.

Wait for 5 minutes.

Find the Raspberry Pi on the router and ssh into it:

```sh
ssh username@<ip>
```

Run the following to install any required updates:

```sh
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### Configure networking

Check what network interfaces are available with this command:

```sh
ip link
```

You should see something like:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
3: wlan0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel state DOWN mode DORMANT group default qlen 1000
```

Pay attention to the name of the ethernet interface (in this case `eth0`).

Run this to see what the netplan file looks like:

```sh
ls /etc/netplan
```

You should see something like `50-cloud-init.yaml`.

Edit the plan with:

```sh
sudo vim /etc/netplan/50-cloud-init.yaml
```

Add an ethernet block like the following:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
      dhcp4-overrides:
        route-metric: 100
```

Also update the existing wifi block (if any), with the following:

```yaml
network:
  wifis:
    wlan0:
      dhcp4-overrides:
        route-metric: 600
```

Save and close.

Run the following to apply the plan & verify that it worked:

```sh
sudo netplan apply
ip link
```

### Set up bootloader (optional)

See also [NVMe](#nvme).

If planning to flash an NVMe drive from the Pi, or just not wanting the NVMe in the bootloader, run:

```sh
sudo rpi-eeprom-config --edit
```

In the editor that opens, change `BOOT_ORDER` to `0xf41`.

Save and close.

## NVMe

If installing an NVMe, first make sure the initial setup is done.

Ensure that [ethernet](#configure-networking) has been set up as the NVMe hat tends to interfere with the wifi radio.

Also follow the steps for [preparing the bootloader](#set-up-bootloader-optional).

Power off the Pi, disconnect it from power & install the NVMe.

Install the NVMe hat & drive, then power up the Pi.
SSH into it and run the following to ensure it was successful:

```sh
lsblk
```

Expected output:

```sh
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
loop0 7:0 0 41.6M 1 loop /snap/snapd/25939
mmcblk0 179:0 0 119.4G 0 disk
├─mmcblk0p1 179:1 0 512M 0 part /boot/firmware
└─mmcblk0p2 179:2 0 118.9G 0 part /
nvme0n1 259:0 0 953.9G 0 disk
```

Download the desired ubuntu image:

```sh
# e.g.
wget https://cdimage.ubuntu.com/ubuntu/releases/26.04/release/ubuntu-26.04-preinstalled-desktop-arm64+raspi.img.xz

# verify checksum
echo '10604098a0c4eeb7359e58e12b01badbce8c74b0d53b414e633ba0b047b512cd ubuntu-26.04-preinstalled-desktop-arm64+raspi.img.xz' | sha256sum --check
```

Write the image to the NVMe identified above:

```sh
xzcat ubuntu-26.04-preinstalled-desktop-arm64+raspi.img.xz | sudo dd of=/dev/nvme0n1 bs=16M status=progress conv=fsync
sync
```

Mount the boot partition:

```sh
sudo mkdir -p /mnt/nvme-boot
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot # usually p1 is the boot/firmware partition

ls /mnt/nvme-boot # you should see config.txt, cmdline.txt, user-data, network-config, etc.
```

Set up SSH

```sh
sudo vim /mnt/nvme-boot/user-data
```

Set the following contents:

```yml
#cloud-config
hostname: raspberry-pi
manage_etc_hosts: true
users:
- name: m3l6h
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  passwd: "$y$jB5$rR5Nrh2Jbx0JttqGHZ1Be/$amVCFDudI7Sf2md7rGZrZ7RAhoTcIlUVoNKHCYFwEH0"
  ssh_authorized_keys:
    - sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIKVVK1doax73LD26k/8ulUA9lcrpvD8WW+l7eACXqESlAAAAD3NzaDpoYXJwb2NyYXRlcw== Primary@YubiKey 2026-03
    - sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMUbMWsvw5fQ1lT4WvPWTMQGRBugogKpAxbZJJ/vVbF4AAAAD3NzaDpoYXJwb2NyYXRlcw== Backup@YubiKey 2026-03
  sudo: ALL=(ALL) NOPASSWD:ALL
enable_ssh: true
ssh_pwauth: false
```

Next edit `/mnt/nvme-boot/network-config` and set the following contents:

```yml
network:
  version: 2

  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.98/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      optional: false
```

Add the following at the bottom of `/mnt/nvme-boot/config.txt`:

```toml
[all]
# Force PCIE Gen 3
dtparam=pciex1
dtparam=pciex1_gen=3
```

Unmount:

```sh
sudo umount /mnt/nvme-boot
sync
```

Poweroff:

```sh
sudo poweroff
```

Remove the microSD & power on again.
Ensure SSH works and Pi is correctly booting from the NVMe.

### troubleshooting

If the Pi fails to boot, ensure the [bootloader was updated](#set-up-bootloader-optional).

If the Pi boots but fails to connect to wifi, ensure that [ethernet was set up](#configure-networking).

## ssh-keys

To set up ssh keys on a Yubikey, do the following:

```sh
# Check PIN status
ykman fido info

# Generate ssh key
ssh-keygen -t ed25519-sk \
	-O resident \
	-O verify-required \ # Optional: Requires PIN
-O application=ssh:m3l6h@ \
	-C "Primary@YubiKey $(date +%Y-%m)" <hostname >.local
```

To store the keys on a luks-encrypted drive, first insert the drive, then:

```sh
sudo cryptsetup luksOpen /dev/sdxx usb
sudo mount /dev/mapper/usb /mnt/usb

cp ~/.ssh/ /mnt/usb <key-name >.pub
cp ~/.ssh/ <key-name >/mnt/usb

sudo umount /mnt/usb
sudo cryptsetup luksClose usb
```
