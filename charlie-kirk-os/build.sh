#!/bin/bash
# Charlie Kirk OS — QEMU Image Builder
# Builds a bootable disk image based on Alpine Linux with full TPUSA theming

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
IMAGE="${SCRIPT_DIR}/charlie-kirk-os.img"
IMAGE_SIZE="2G"

ALPINE_VERSION="3.21.3"
ALPINE_ARCH="x86_64"
ALPINE_ROOTFS="alpine-minirootfs-${ALPINE_VERSION}-${ALPINE_ARCH}.tar.gz"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/${ALPINE_ARCH}/${ALPINE_ROOTFS}"

MOUNT_DIR="${BUILD_DIR}/mnt"

RED='\033[1;31m'
WHITE='\033[1;37m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${RED}  ██████╗██╗  ██╗ █████╗ ██████╗ ██╗     ██╗███████╗    ██╗  ██╗██╗██████╗ ██╗  ██╗${NC}"
    echo -e "${WHITE}  ██╔════╝██║  ██║██╔══██╗██╔══██╗██║     ██║██╔════╝    ██║ ██╔╝██║██╔══██╗██║ ██╔╝${NC}"
    echo -e "${BLUE}  ██║     ███████║███████║██████╔╝██║     ██║█████╗      █████╔╝ ██║██████╔╝█████╔╝ ${NC}"
    echo -e "${WHITE}  ██║     ██╔══██║██╔══██║██╔══██╗██║     ██║██╔══╝      ██╔═██╗ ██║██╔══██╗██╔═██╗ ${NC}"
    echo -e "${RED}  ╚██████╗██║  ██║██║  ██║██║  ██║███████╗██║███████╗    ██║  ██╗██║██║  ██║██║  ██╗${NC}"
    echo -e "   OS BUILD SYSTEM — ${YELLOW}\"Socialism Ends Here\"${NC}"
    echo ""
}

log()  { echo -e "${WHITE}[BUILD]${NC} $*"; }
ok()   { echo -e "${YELLOW}  [OK]${NC} $*"; }
err()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

cleanup() {
    log "Cleaning up mounts..."
    if mountpoint -q "${MOUNT_DIR}/proc" 2>/dev/null; then
        umount "${MOUNT_DIR}/proc" 2>/dev/null || true
    fi
    if mountpoint -q "${MOUNT_DIR}/sys" 2>/dev/null; then
        umount "${MOUNT_DIR}/sys" 2>/dev/null || true
    fi
    if mountpoint -q "${MOUNT_DIR}/dev" 2>/dev/null; then
        umount "${MOUNT_DIR}/dev" 2>/dev/null || true
    fi
    if mountpoint -q "${MOUNT_DIR}" 2>/dev/null; then
        umount "${MOUNT_DIR}" 2>/dev/null || true
    fi
    if [ -n "${PART_LOOP:-}" ]; then
        losetup -d "${PART_LOOP}" 2>/dev/null || true
    fi
    if [ -n "${LOOP_DEV:-}" ]; then
        losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

banner

# ─── Step 1: Download Alpine miniroot ────────────────────────────────────────
log "Step 1/8 — Downloading Alpine Linux ${ALPINE_VERSION} miniroot..."
mkdir -p "${BUILD_DIR}"
if [ ! -f "${BUILD_DIR}/${ALPINE_ROOTFS}" ]; then
    wget -q --show-progress -O "${BUILD_DIR}/${ALPINE_ROOTFS}" "${ALPINE_URL}"
    ok "Downloaded ${ALPINE_ROOTFS}"
else
    ok "Cached rootfs found, skipping download."
fi

# ─── Step 2: Create disk image ───────────────────────────────────────────────
log "Step 2/8 — Creating ${IMAGE_SIZE} disk image..."
qemu-img create -f raw "${IMAGE}" "${IMAGE_SIZE}"
ok "Created ${IMAGE}"

# ─── Step 3: Partition the image ─────────────────────────────────────────────
log "Step 3/8 — Partitioning disk (1MB BIOS boot + rest ext4)..."
parted -s "${IMAGE}" \
    mklabel msdos \
    mkpart primary ext4 1MiB 100% \
    set 1 boot on
ok "Partitioned image"

# ─── Step 4: Format and mount ────────────────────────────────────────────────
log "Step 4/8 — Formatting and mounting filesystem..."
LOOP_DEV=$(losetup --find --show "${IMAGE}")
ok "Loop device: ${LOOP_DEV}"

# Use offset to access the partition directly (partition 1 starts at 1MiB = 1048576 bytes)
PART_LOOP=$(losetup --find --show --offset 1048576 "${IMAGE}")
ok "Partition loop: ${PART_LOOP}"

# Disable 64bit and metadata_csum so GRUB's ext2 module can read the filesystem
mkfs.ext4 -q -L "TPUSA-OS" -O ^64bit,^metadata_csum "${PART_LOOP}"
mkdir -p "${MOUNT_DIR}"
mount "${PART_LOOP}" "${MOUNT_DIR}"
ok "Mounted at ${MOUNT_DIR}"

# ─── Step 5: Extract Alpine rootfs ───────────────────────────────────────────
log "Step 5/8 — Extracting Alpine Linux rootfs..."
tar -xzf "${BUILD_DIR}/${ALPINE_ROOTFS}" -C "${MOUNT_DIR}"
ok "Rootfs extracted"

# ─── Step 6: Apply Charlie Kirk overlay ──────────────────────────────────────
log "Step 6/8 — Applying TPUSA overlay (theming & custom commands)..."

# Copy overlay files
cp -r "${SCRIPT_DIR}/overlay/." "${MOUNT_DIR}/"

# Make custom binaries executable
chmod +x "${MOUNT_DIR}/usr/local/bin/kirk-quote"
chmod +x "${MOUNT_DIR}/usr/local/bin/kirk-facts"
chmod +x "${MOUNT_DIR}/usr/local/bin/kirk-debate"
chmod +x "${MOUNT_DIR}/usr/local/bin/tpusa-news"

# Write a proper /etc/issue (pre-login banner)
cat > "${MOUNT_DIR}/etc/issue" << 'ISSUE'

  ████████╗██████╗ ██╗   ██╗███████╗ █████╗      ██████╗ ███████╗
  ╚══██╔══╝██╔══██╗██║   ██║██╔════╝██╔══██╗    ██╔═══██╗██╔════╝
     ██║   ██████╔╝██║   ██║███████╗███████║    ██║   ██║███████╗
     ██║   ██╔═══╝ ██║   ██║╚════██║██╔══██║    ██║   ██║╚════██║
     ██║   ██║     ╚██████╔╝███████║██║  ██║    ╚██████╔╝███████║
     ╚═╝   ╚═╝      ╚═════╝ ╚══════╝╚═╝  ╚═╝     ╚═════╝ ╚══════╝

  Charlie Kirk Operating System v1.0 — "Facts Don't Care About Your Feelings"
  Kernel: \r  |  Host: \n  |  Arch: \m

  Login as 'root' (no password required — freedom needs no gatekeeper)

ISSUE

# Write /etc/os-release
cat > "${MOUNT_DIR}/etc/os-release" << 'OSRELEASE'
NAME="Charlie Kirk OS"
VERSION="1.0"
ID=tpusa
ID_LIKE=alpine
VERSION_ID="1.0"
PRETTY_NAME="Charlie Kirk OS 1.0 (TPUSA Edition)"
HOME_URL="https://www.tpusa.com"
SUPPORT_URL="https://www.charliekirk.com"
BUG_REPORT_URL="https://twitter.com/charliekirk11"
OSRELEASE

# /etc/inittab — autologin on tty1 + serial console
cat > "${MOUNT_DIR}/etc/inittab" << 'INITTAB'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Autologin as root on console
tty1::respawn:/sbin/agetty --autologin root --noclear 38400 tty1
ttyS0::respawn:/sbin/agetty --autologin root -L 115200 ttyS0 vt100

::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
INITTAB

# /etc/profile — show MOTD and load kirk.sh
cat > "${MOUNT_DIR}/etc/profile" << 'PROFILE'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="${TERM:-linux}"
export HOME="/root"

# Run all profile.d scripts
for f in /etc/profile.d/*.sh; do
    [ -r "$f" ] && . "$f"
done

# Show MOTD on login
if [ -f /etc/motd ] && [ "${MOTD_DISPLAYED:-0}" != "1" ]; then
    export MOTD_DISPLAYED=1
    cat /etc/motd
    echo ""
    kirk-quote
fi
PROFILE

# /root/.profile
cat > "${MOUNT_DIR}/root/.profile" << 'ROOTPROFILE'
. /etc/profile
ROOTPROFILE

# /root/.ashrc — for non-login ash shells
cat > "${MOUNT_DIR}/root/.ashrc" << 'ASHRC'
. /etc/profile.d/kirk.sh
ASHRC

# DNS
echo "nameserver 8.8.8.8" > "${MOUNT_DIR}/etc/resolv.conf"

ok "Overlay applied"

# ─── Step 7: Chroot setup — install GRUB + packages ──────────────────────────
log "Step 7/8 — Chroot: installing packages (GRUB, util-linux, bash)..."

mount --bind /proc "${MOUNT_DIR}/proc"
mount --bind /sys  "${MOUNT_DIR}/sys"
mount --bind /dev  "${MOUNT_DIR}/dev"
# Ensure loop devices are accessible inside chroot
mknod -m 660 "${MOUNT_DIR}/dev/loop0" b 7 0 2>/dev/null || true
for i in $(seq 0 7); do
    mknod -m 660 "${MOUNT_DIR}/dev/loop${i}" b 7 ${i} 2>/dev/null || true
done
# Copy host CA certs so apk can verify HTTPS inside chroot
# Alpine OpenSSL uses /etc/ssl/cert.pem; Ubuntu uses /etc/ssl/certs/ca-certificates.crt
mkdir -p "${MOUNT_DIR}/etc/ssl/certs"
cp /etc/ssl/certs/ca-certificates.crt "${MOUNT_DIR}/etc/ssl/certs/ca-certificates.crt" 2>/dev/null || true
cp /etc/ssl/certs/ca-certificates.crt "${MOUNT_DIR}/etc/ssl/cert.pem" 2>/dev/null || true

# Set up repos and install packages inside the image
chroot "${MOUNT_DIR}" /bin/sh -c "
    set -e
    # Configure Alpine repos
    echo 'https://dl-cdn.alpinelinux.org/alpine/v3.21/main' > /etc/apk/repositories
    echo 'https://dl-cdn.alpinelinux.org/alpine/v3.21/community' >> /etc/apk/repositories

    # Update and install (openrc first so rc-update is available)
    apk update -q
    apk add -q openrc grub grub-bios util-linux bash shadow

    # Set root password to nothing (autologin anyway)
    passwd -d root

    # Enable essential services (|| true tolerates missing services)
    rc-update add devfs sysinit    || true
    rc-update add dmesg sysinit    || true
    rc-update add udev sysinit     || true

    rc-update add hostname boot    || true
    rc-update add networking boot  || true
    rc-update add modules boot     || true

    rc-update add local default    || true

    # Set hostname
    echo 'tpusa-os' > /etc/hostname

    echo '[CHROOT] Packages installed.'
"

# ─── Install GRUB to the image ────────────────────────────────────────────────
log "  Configuring GRUB with serial console + TPUSA theme..."

# Set /etc/default/grub so grub-mkconfig (triggered by kernel install) uses serial + label
cat > "${MOUNT_DIR}/etc/default/grub" << 'GRUBDEFAULT'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="Charlie Kirk OS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"
GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0 root=LABEL=TPUSA-OS rw"
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"
GRUB_COLOR_NORMAL="light-red/black"
GRUB_COLOR_HIGHLIGHT="white/red"
GRUB_DISABLE_OS_PROBER=true
GRUBDEFAULT

mkdir -p "${MOUNT_DIR}/boot/grub"

GRUB_DISK="/dev/$(basename ${LOOP_DEV})"
# Run grub-install inside chroot; embed ext2 and part_msdos in core so it can
# read the partition without needing extra modules from disk first.
chroot "${MOUNT_DIR}" /bin/sh -c "
    grub-install --target=i386-pc \
        --boot-directory=/boot \
        --modules='ext2 part_msdos' \
        --recheck \
        ${GRUB_DISK}
    echo '[CHROOT] GRUB installed.'
"

# Install kernel (apk post-install runs grub-mkconfig, which reads /etc/default/grub)
log "  Installing Linux kernel..."
chroot "${MOUNT_DIR}" /bin/sh -c "
    apk add -q linux-lts
    echo '[CHROOT] Kernel installed.'
"

# Overwrite grub.cfg with our fully themed version
log "  Writing themed GRUB menu..."
cat > "${MOUNT_DIR}/boot/grub/grub.cfg" << 'GRUBCFG'
serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
terminal_input  console serial
terminal_output console serial

set default=0
set timeout=5
set timeout_style=menu

set color_normal=light-red/black
set color_highlight=white/red

insmod ext2
search --no-floppy --label --set=root TPUSA-OS

menuentry "  Charlie Kirk OS v1.0 -- FREEDOM EDITION" {
    insmod gzio
    linux   /boot/vmlinuz-lts root=/dev/sda1 rw rootwait rootfstype=ext4 quiet loglevel=3 console=ttyS0,115200n8 console=tty0
    initrd  /boot/initramfs-lts
}

menuentry "  Charlie Kirk OS (verbose -- No Censorship Mode)" {
    insmod gzio
    linux   /boot/vmlinuz-lts root=/dev/sda1 rw rootwait rootfstype=ext4 console=ttyS0,115200n8 console=tty0
    initrd  /boot/initramfs-lts
}

menuentry "  Reboot  (No Retreat, No Surrender)" {
    reboot
}

menuentry "  Halt    (Mission Accomplished)" {
    halt
}
GRUBCFG

ok "Chroot setup complete"

# ─── Step 8: Unmount ─────────────────────────────────────────────────────────
log "Step 8/8 — Unmounting and finalizing image..."
umount "${MOUNT_DIR}/proc"
umount "${MOUNT_DIR}/sys"
umount "${MOUNT_DIR}/dev"
umount "${MOUNT_DIR}"
losetup -d "${PART_LOOP}"
PART_LOOP=""
losetup -d "${LOOP_DEV}"
LOOP_DEV=""

ok "Image complete: ${IMAGE}"

echo ""
echo -e "${RED}  ════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}   BUILD COMPLETE — Charlie Kirk OS is ready to run!${NC}"
echo -e "${YELLOW}   Run:  ./run.sh${NC}"
echo -e "${RED}  ════════════════════════════════════════════════════${NC}"
echo ""
