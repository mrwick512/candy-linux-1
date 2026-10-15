#!/bin/sh
# Runs once on the first boot of an installed system (it also runs in the live
# session, where its marker is thrown away at shutdown).
#
# 1. The installer's keyboard page writes a generic "pc105" model into
#    /etc/default/keyboard. Put the Chromebook model back so right-Alt works
#    as the Fn layer.
# 2. Add noatime to an ext4 root: fewer metadata writes on the eMMC.
# 3. Remove the live-session "Install" launcher from installed systems.
set -u

STATE=/var/lib/candy
STAMP="$STATE/firstboot.done"
KBD=/etc/default/keyboard

[ -e "$STAMP" ] && exit 0

# 1. keyboard model
if [ -f "$KBD" ]; then
	if grep -q '^XKBMODEL=' "$KBD"; then
		sed -i 's/^XKBMODEL=.*/XKBMODEL="chromebook"/' "$KBD"
	else
		echo 'XKBMODEL="chromebook"' >> "$KBD"
	fi
fi

# Everything below only makes sense on an installed system, not the live one.
if [ ! -d /run/live ]; then
	# 2. noatime on an ext4 root
	if [ "$(findmnt -n -o FSTYPE / 2>/dev/null)" = "ext4" ] && [ -f /etc/fstab ]; then
		if ! awk '$2=="/" && $3=="ext4" && $4 ~ /noatime/ {found=1} END{exit !found}' /etc/fstab; then
			cp -a /etc/fstab /etc/fstab.candy-bak
			awk 'BEGIN{OFS="\t"} $1 !~ /^#/ && $2=="/" && $3=="ext4" {$4=$4",noatime"} {print}' \
				/etc/fstab.candy-bak > /etc/fstab
		fi
	fi

	# 3. installer launcher
	rm -f /etc/skel/Desktop/install-candy-linux.desktop /home/*/Desktop/install-candy-linux.desktop
fi

mkdir -p "$STATE"
touch "$STAMP"
exit 0
