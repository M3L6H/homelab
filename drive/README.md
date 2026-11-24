# drive

Setup instructions for drives.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [initial partitioning](#initial-partitioning)
- [luks setup](#luks-setup)
- [copy data](#copy-data)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## initial partitioning

Start by identifying the drive:

```sh
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL
```

**THE FOLLOWING STEPS WILL WIPE THE DRIVE**

Use fdisk to create a partition:

```sh
sudo fdisk '/dev/<sdX>'
```

Inside `fdisk`, use `g` to create a new GPT partition table.
Then use `n` to create a new partition.
Accept all defaults for a single full-size partition.
If prompted about VFAT (from old data), use Y to remove.
Finish with `w` to write and exit.

Verify with:

```sh
lsblk '/dev/<sdX>'
```

The new partition should be visible.

## luks setup

To create an encrypted drive with luks, use the following:

```sh
sudo cryptsetup luksFormat --type luks2 '/dev/<sdX>'
```

Enroll a recovery key with:

```sh
sudo systemd-cryptenroll --recovery-key '/dev/<sdX>'
```

Enroll a fido2 key with:

```sh
sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=no <luks device>

# If running into issues with multiple FIDO devices detected, identify hidraw path with this:
sudo systemd-cryptenroll --fido2-device=list

# Then re-run
sudo systemd-cryptenroll --fido2-device=<hidraw path> --fido2-with-client-pin=no <luks device>
```

To verify successful fido2 key enrollment, use this command:

```sh
sudo cryptsetup luksOpen --test-passphrase --token-id <id> --verbose --token-only --debug <luks device>
```

If any slots need to be wiped, use the following:

```sh
# Identify slot
sudo systemd-cryptenroll <luks device>

# Wipe slot
sudo systemd-cryptenroll --wipe-slot=<slog> <luks device>
```

## copy data

To copy data from one drive to another, use the following:

```sh
sudo rsync -avh --info=progress2 --ignore-existing '<source>/' '<dest>/'
```
