#!/bin/sh
# Apply the Candy Linux tuning to an ALREADY INSTALLED Debian/Ubuntu-based system
# on a Dell Chromebook 11 3120 ("candy"), instead of building the ISO.
#
#   sudo tools/candy-apply.sh [--dry-run] [--no-packages] [--force]
#
# What it does: installs a few packages (TLP, zram, ALSA UCM, eMMC/input tools),
# copies the files under config/includes.chroot_after_packages into /, enables the
# Candy systemd units and runs the first-boot adjustments (Chromebook keyboard
# model, noatime on an ext4 root). Existing files are kept as numbered backups.
# It never replaces /etc/default/keyboard wholesale, so your layout stays yours.
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
SRC="$HERE/config/includes.chroot_after_packages"
DRY=0
PKGS=1
FORCE=0

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

for a in "$@"; do
	case "$a" in
		--dry-run) DRY=1 ;;
		--no-packages) PKGS=0 ;;
		--force) FORCE=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown option: $a" >&2; usage; exit 2 ;;
	esac
done

run() {
	if [ "$DRY" = 1 ]; then echo "+ $*"; else "$@"; fi
}

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
	echo "Run as root (sudo), or use --dry-run to preview." >&2
	exit 1
fi

# Refuse to tune the wrong machine unless told otherwise.
model="$(cat /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name 2>/dev/null || true)"
case "$model" in
	*[Cc]andy*) ;;
	*)
		if [ "$FORCE" = 0 ]; then
			echo "This does not look like a Dell Chromebook 11 3120 (DMI: $(echo "$model" | tr '\n' ' '))." >&2
			echo "Use --force to apply anyway." >&2
			exit 1
		fi
		;;
esac

if [ "$PKGS" = 1 ] && command -v apt-get >/dev/null 2>&1; then
	run apt-get update
	# Required for the tweaks to have any effect.
	run apt-get install -y tlp alsa-utils alsa-ucm-conf mmc-utils powertop i2c-tools evtest libinput-tools
	# Best-effort: names/availability differ between distributions.
	for pkg in systemd-zram-generator firmware-iwlwifi firmware-intel-sound firmware-sof-signed; do
		run apt-get install -y "$pkg" || echo "skipped $pkg (not available here)"
	done
fi

# Copy the overlay, keeping backups of anything we replace.
(
	cd "$SRC"
	find . -type f | while read -r f; do
		case "$f" in
			./etc/default/keyboard|./etc/skel/*) continue ;;
		esac
		run install -D -m "$(stat -c %a "$f")" --backup=numbered "$f" "/${f#./}"
	done
)

run chmod 0755 /usr/local/bin/candy-diag /usr/local/lib/candy/touchpad-wakeup.sh /usr/local/lib/candy/firstboot.sh
run systemctl daemon-reload
run systemctl enable --now candy-touchpad-wakeup.service
run systemctl enable tlp.service
run sysctl --system
run rm -f /var/lib/candy/firstboot.done
run /usr/local/lib/candy/firstboot.sh

echo
echo "Done. Reboot to activate zram swap, the keyboard model and the journal limits."
echo "Then run: sudo candy-diag"
