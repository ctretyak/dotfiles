---
name: setup-fingerprint
description: Set up fingerprint authentication on Linux (fprintd + custom libfprint for unsupported Goodix MOH readers)
allowed-tools: Bash Read Write Edit Grep Glob Agent
---

## Goal

Set up fingerprint authentication on the current machine. Handles both mainline-supported readers and unsupported Goodix MOH (Match-On-Host) chips that need a custom libfprint build.

## Step 1: Detect hardware

```bash
lsusb | grep -i fingerprint
# Also check: lsusb | grep -i goodix
```

Check if the detected USB ID is supported by mainline libfprint:
- Look at https://gitlab.freedesktop.org/libfprint/libfprint/-/tree/master/libfprint/drivers for supported devices
- If supported: skip to Step 4 (just install fprintd)

## Step 2: Goodix MOH — build custom libfprint (if needed)

Known unsupported Goodix MOH chips that work with gulp's fork:
- `27c6:5117` — Goodix fingerprint reader (tested, works)
- `27c6:5110` — also supported by the same driver

### 2a: Determine firmware version

```bash
# Clone diagnostic tool
cd /tmp && git clone https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git
cd goodix-fp-dump

# Create stub modules for SPI (not needed for USB)
echo "" > periphery.py
echo "" > spidev.py

# Install USB dependencies
sudo pacman -S python-pyusb python-crcmod

# Run to get device info (firmware version, PSK hash, etc.)
python tool.py
```

The output shows firmware version (e.g. `GF_ST411SEC_APP_12109`) and PSK hash.

### 2b: Check PSK status

If PMK Hash is NOT all zeros, a firmware reflash is needed to reset PSK to zero:
```bash
# Download firmware matching the device
cd /tmp/goodix-fp-dump
mkdir -p firmware/51x7
# Get firmware from: https://github.com/goodix-fp-linux-dev/goodix-firmware
# Place the .bin file in firmware/51x7/

# Flash (WARNING: can brick the device — read warnings carefully)
python run_5117.py
# Select option to erase firmware, then flash new firmware
```

### 2c: Build custom libfprint package

Install build dependencies:
```bash
sudo pacman -S git meson ninja gcc gobject-introspection glib2-devel libgusb openssl pixman opencv libgudev
```

Create a PKGBUILD and build:
```bash
mkdir -p /tmp/libfprint-goodix5117-build
cat > /tmp/libfprint-goodix5117-build/PKGBUILD << 'PKGEOF'
pkgname=libfprint-goodix5117
pkgver=1.94.5
pkgrel=1
pkgdesc='Library for fingerprint readers — patched with Goodix 27c6:5117 support'
arch=(x86_64)
url='https://github.com/gulp/libfprint'
license=(LGPL-2.1-or-later)
depends=(gcc-libs glib2 glibc libgudev libgusb openssl pixman opencv)
makedepends=(git meson ninja gobject-introspection glib2-devel)
provides=(libfprint libfprint=$pkgver libfprint-2.so=2-64)
conflicts=(libfprint)
replaces=(libfprint)
_commit=7b4630ff2bbcf8d292f325b30f84d064d0923c15
source=("git+https://github.com/gulp/libfprint.git#commit=$_commit")
sha256sums=('SKIP')

build() {
  cd libfprint
  arch-meson build \
    -Ddrivers=goodixtls511 \
    -Dudev_hwdb=disabled \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=true
  meson compile -C build
}

package() {
  cd libfprint
  meson install -C build --destdir "$pkgdir"
}
PKGEOF

cd /tmp/libfprint-goodix5117-build && makepkg -si --noconfirm
```

## Step 3: Verify driver loads

```bash
# Restart fprintd to pick up new library
sudo systemctl restart fprintd.service 2>/dev/null
fprintd-list $USER
# Should show the device, not "No devices available"
```

## Step 4: Install and configure fprintd

```bash
sudo pacman -S --needed fprintd
```

fprintd uses D-Bus activation — do NOT `systemctl enable` it.

### Suspend hook (prevents resume issues)

```bash
sudo tee /usr/lib/systemd/system-sleep/fprintd-suspend.sh << 'EOF'
#!/bin/bash
case "$1" in
  pre) systemctl stop fprintd.service 2>/dev/null ;;
esac
EOF
sudo chmod 755 /usr/lib/systemd/system-sleep/fprintd-suspend.sh
```

### GDM integration

GDM already ships `/etc/pam.d/gdm-fingerprint` with `pam_fprintd.so` — no PAM edits needed.
GNOME Settings > Users > Fingerprint Login provides the enrollment UI.

## Step 5: Enroll fingerprints

```bash
fprintd-enroll                           # default: right index finger
fprintd-enroll -f right-middle-finger    # additional fingers
fprintd-enroll -f left-index-finger
```

Verify:
```bash
fprintd-verify
```

If "No enough keypoints" or "verify-no-match": re-enroll with firm, centered finger placement. The 80x88 sensor is small.

## Security notes

- MOH architecture: fingerprint image travels over USB to host CPU — less secure than MOC (Match-On-Chip)
- Zero PSK on Linux: TLS encryption between chip and host is trivial (Windows driver used real PSK)
- Practical risk is low: exploitation requires physical access inside the laptop + USB sniffer
- LUKS disk encryption is the real protection against theft — fingerprint is convenience only
- CVE-2024-37408: fingerprint hijacking for CLI sudo/su — affects all fprintd, not specific to this driver
