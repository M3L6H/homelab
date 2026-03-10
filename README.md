<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [homelab](#homelab)
  - [initial setup](#initial-setup)
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

```sh
# Install tools
sudo apt install -y curl fail2ban git wget

# Enable firewall (allow ssh)
sudo ufw allow OpenSSH
sudo ufw --force enable

# Disable password-based ssh
sudo vi /etc/ssh/sshd_config
# set: PasswordAuthentication no
# :wq
sudo systemctl restart ssh
```

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
