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

ssh back into the machine and install some basic tools & do some security hardening:

`TODO`

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
