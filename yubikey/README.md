# yubikey

Setup instructions for YubiKey.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->

<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

**Table of Contents**

- [initial setup](#initial-setup)
  - [check status](#check-status)
  - [change openpgp pins](#change-openpgp-pins)
  - [require user presence for openpgp operations](#require-user-presence-for-openpgp-operations)
  - [change fido pin](#change-fido-pin)
- [import gpg keys from offline luks usb](#import-gpg-keys-from-offline-luks-usb)
  - [Rotate subkeys](#rotate-subkeys)
  - [Import keys](#import-keys)
  - [Clean up](#clean-up)
- [ssh key setup](#ssh-key-setup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## initial setup

Before performing any of the steps below, ensure the prerequisites are available:

```sh
command -v ykman gpg scdaemon pcscd
```

If the prerequisites are not available, you can install them manually or use the provided nix shell.

If you have `nix-direnv` available:

```sh
echo 'use flake' >>.envrc && direnv allow
```

Or just using `nix`:

```sh
nix shell
```

It is **highly recommended** that these operations be performed offline.
To go offline, check what interface is currently in use for connecting to the internet:

```sh
ip link show
```

Disable the active device to disconnect from the internet:

```sh
nmcli dev disconnect <device>
```

### check status

All of these commands should be run within the shell.

```sh
ykman info
ykman openpgp info
ykman fido info
gpg --card-status
```

### change openpgp pins

Default pin: 123456
Default admin pin: 12345678

The updated pins should be different.
Using the same value for both user pin and admin pin eliminates the recovery safety net.
It also exposes card configuration whenever you type your daily pin.

```sh
ykman openpgp access change-pin
ykman openpgp access change-admin-pin
```

### change fido pin

```sh
ykman fido access change-pin
```

## register key with luks

For any devices with luks devices that the key should unlock, run the following:

```sh
# Identify your luks device
lsblk

# List slots
sudo systemd-cryptenroll <luks device>

# Enroll yubikey
sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=no <luks device>

# If running into issues with multiple FIDO devices detected, identify hidraw path with this:
sudo systemd-cryptenroll --fido2-device=list

# Then re-run
sudo systemd-cryptenroll --fido2-device=<hidraw path> --fido2-with-client-pin=no <luks device>

# Full dump
sudo cryptsetup luksDump <luks device>
```

If any slots need to be wiped, use the following:

```sh
# Identify slot
sudo systemd-cryptenroll <luks device>

# Wipe slot
sudo systemd-cryptenroll --wipe-slot=<slog> <luks device>
```

## set up gpg

Start by editing card details with:

```sh
gpg --card-edit
```

Use `admin` to enable admin mode, then update:

- `name`
- `url` (should be: https://keys.openpgp.org/vks/v1/by-fingerprint/5FDB05DA213CC2272006F5513A2ED28CE6DE10FD)
- `lang` (en)
- `uif 2 on`
- `uif 3 on`

Then use `quit` to save changes and quit.

### set up usb

Plug offline usb in and mount it:

```sh
lsblk # Identify device
sudo cryptsetup luksOpen '/dev/<device>' usb
sudo mkdir /mnt/usb
sudo mount /dev/mapper/usb /mnt/usb
```

Create temp gnupghome and set up pinentry:

```sh
export GNUPGHOME="$(mktemp -d -p /dev/shm)"
chmod 700 "$GNUPGHOME"
echo "pinentry-program $(which pinentry-curses)" >>"$GNUPGHOME/gpg-agent.conf"
gpgconf --kill gpg-agent
```

Import secret:

```sh
gpg --import '/mnt/usb/gpg/<year>/master-secret.asc'
```

List keys:

```sh
gpg -K
```

Example output (note the lack of #):

```sh
/dev/shm/tmp.TqjbtchD6O/pubring.kbx
-----------------------------------
sec   ed25519/1234567890ABCDEF 2025-12-21 [SC]
      1234567890ABCDEF1234567890ABCDEF1234567
uid                 [ unknown] John Doe <jd@example.com>
ssb   cv25519/234567890ABCDEF1 2025-12-21 [E]
ssb   ed25519/34567890ABCDEF12 2025-12-21 [S] [expires: 2027-12-21]
ssb   cv25519/4567890ABCDEF123 2025-12-21 [E] [expires: 2027-12-21]
ssb   ed25519/567890ABCDEF1234 2025-12-21 [A] [expires: 2027-12-21]
```

### Rotate subkeys

Edit the key

```sh
gpg --expert --edit-key <key id>
```

In the gpg prompt, use `key <index>` to select keys to revoke.
Use `revkey` to revoke them.

Use `addkey` to add new subkeys.

Use `save` to exit.

Update keys on USB:

```sh
KEYID='<keyid>'
DIR="/mnt/usb/gpg/$(date +%Y)" # Update if using custom directory
sudo mkdir "$DIR" &&
	gpg --armor --export-secret-keys "$KEYID" >master-secret.asc &&
	sudo mv master-secret.asc "${DIR}/" &&
	gpg --armor --export-secret-subkeys "$KEYID" >subkeys.asc &&
	sudo mv subkeys.asc "${DIR}/" &&
	gpg --armor --export "$KEYID" >pub.asc &&
	sudo mv pub.asc "${DIR}/"
```

### Import keys

```sh
gpg --edit-key <keyid>
```

In the gpg prompt, select the signing key with `key <index>`.
Use `keytocard` to transfer the key, then `key <index>` again to deselect that key.
Repeat for encryption and authentication keys.

Use `save` to exit.

### Clean up

Run the following to clean up the temporary gpg session:

```sh
gpgconf --kill gpg-agent && rm -rf "$GNUPGHOME" && unset GNUPGHOME
```

Confirm everything is correct with

```sh
gpg --card-status
gpg -K
```

Unmount the drive:

```sh
sudo umount /mnt/usb
sudo cryptsetup luksClose usb
```

Unplug usb.

Re-enable internet:

```sh
nmcli dev connect <device>
```

### Update keys

Ensure that above steps are performed for only one key at a time.

Use the following to update gpg keys on `keys.openpgp.org`:

```sh
gpg --send-keys '<key fingerprint>'
```

To update on GitHub, delete the existing key and add the updated key retrieved using the following:

```sh
gpg --armor --export <keyid>
```

To update on servers, first ensure the running ssh agent is the gpg agent.

Verify with `ssh-add -L`.

Then use this to generate/update the public ssh key:

```sh
YEAR="$(date +%Y)" # Update if using custom identifier
ssh-add -L >"~/.ssh/id_gpg_${YEAR}.pub"
chmod 600 "~/.ssh/id_gpg_${YEAR}.pub"
ln "~/.ssh/id_gpg_${YEAR}.pub" ~/.ssh/id_gpg.pub
```

Now for each server, do:

```sh
ssh-copy-id -f -i "~/.ssh/id_gpg_<year>.pub" -o "IdentityFile ~/.ssh/<old id file>" '<user>@<host>'
```

Verify with

```sh
ssh -i "~/.ssh/id_gpg_<year>.pub" '<user>@<host>'
```

While in the box, remove the old key on the server from `~/.ssh/authorized_keys`.

## ssh key setup

**Deprecated. Prefer using gpg ssh key instead.**

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

cp ~/.ssh/ /mnt/usb '<key-name>.pub'
cp ~/.ssh/ '<key-name>/mnt/usb'

sudo umount /mnt/usb
sudo cryptsetup luksClose usb
```
