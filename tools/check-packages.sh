#!/bin/sh
# Fail fast: confirm every package in config/package-lists/candy.list.chroot exists in
# Debian (main contrib non-free-firmware) BEFORE spending 20+ minutes on a build.
# Needs apt and network access; run as root or any user (it uses its own temp apt state).
set -eu

DIST="${DIST:-trixie}"
HERE=$(cd "$(dirname "$0")/.." && pwd)
LIST="$HERE/config/package-lists/candy.list.chroot"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "deb http://deb.debian.org/debian $DIST main contrib non-free-firmware" > "$TMP/sources.list"
mkdir -p "$TMP/lists/partial" "$TMP/cache/archives/partial"
APT="-o Dir::Etc::sourcelist=$TMP/sources.list -o Dir::Etc::sourceparts=/dev/null -o Dir::State::lists=$TMP/lists -o Dir::Cache=$TMP/cache"

echo "Fetching the $DIST package index..."
# shellcheck disable=SC2086
apt-get $APT update -q

missing=""
count=0
for pkg in $(sed -e 's/#.*//' "$LIST" | tr -s ' \t' '\n' | grep -v '^$'); do
	count=$((count + 1))
	# shellcheck disable=SC2086
	if ! apt-cache $APT show "$pkg" >/dev/null 2>&1; then
		missing="$missing $pkg"
	fi
done

if [ -n "$missing" ]; then
	echo "ERROR: these packages do not exist in $DIST:$missing" >&2
	echo "Remove or rename them in config/package-lists/candy.list.chroot." >&2
	exit 1
fi

echo "OK: all $count packages exist in $DIST."
