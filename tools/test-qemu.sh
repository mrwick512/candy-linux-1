#!/bin/sh
# Boot the built ISO in QEMU (UEFI, 2 GB RAM, 2 CPUs) to sanity-check it before
# flashing a USB stick. QEMU can't emulate the candy's hardware, so this only
# proves the image boots to the desktop and the installer launches.
#
#   tools/test-qemu.sh [path/to/candy-linux.iso]
#
# Needs: qemu-system-x86_64 and OVMF (Debian/Ubuntu: apt install qemu-system-x86 ovmf)
set -eu

ISO="${1:-$(find . -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "No ISO found. Pass its path as an argument." >&2; exit 1; }

OVMF=""
for f in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF.fd /usr/share/qemu/OVMF.fd /usr/share/edk2/ovmf/OVMF.fd; do
	[ -f "$f" ] && { OVMF="$f"; break; }
done
[ -n "$OVMF" ] || { echo "OVMF firmware not found (install the 'ovmf' package)." >&2; exit 1; }

ACCEL=""
[ -w /dev/kvm ] && ACCEL="-enable-kvm -cpu host"

# shellcheck disable=SC2086
exec qemu-system-x86_64 $ACCEL \
	-machine q35 -m 2048 -smp 2 \
	-bios "$OVMF" \
	-drive file="$ISO",media=cdrom,readonly=on \
	-device intel-hda -device hda-duplex \
	-device virtio-vga \
	-nic user,model=virtio-net-pci
