#!/bin/sh
# Build the Candy Linux ISO.
#
#   ./build.sh            # native on a Debian host running as root, otherwise inside Docker
#   ./build.sh native     # force native (must be root on Debian)
#   ./build.sh docker     # force a debian:trixie container (works on Windows/macOS/Ubuntu)
#
# Output: candy-linux-*.iso and SHA256SUMS in the current directory.
set -eu

MODE="${1:-}"

native_build() {
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get install -y --no-install-recommends \
		live-build debootstrap xorriso squashfs-tools mtools dosfstools ca-certificates \
		syslinux syslinux-common isolinux grub-efi-amd64-bin grub-pc-bin
	# Exec bits are lost when a repo is unpacked on Windows or uploaded as a zip.
	chmod +x auto/* tools/*.sh config/hooks/live/*.hook.chroot
	./tools/check-packages.sh
	lb clean --purge || true
	lb config
	lb build
	for iso in *.iso; do
		[ -e "$iso" ] || { echo "Build finished but no ISO was produced - see build.log" >&2; exit 1; }
		case "$iso" in candy-linux-*) ;; *) mv "$iso" "candy-linux-$(date +%Y%m%d)-${iso}" ;; esac
	done
	sha256sum candy-linux-*.iso > SHA256SUMS
	ls -lh candy-linux-*.iso SHA256SUMS
}

if [ "$MODE" = "native-inner" ]; then
	native_build
	exit 0
fi

if [ -z "$MODE" ]; then
	MODE=docker
	if [ "$(id -u)" = 0 ] && [ -r /etc/os-release ]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		[ "${ID:-}" = "debian" ] && MODE=native
	fi
fi

case "$MODE" in
	native)
		[ "$(id -u)" = 0 ] || { echo "Native builds need root." >&2; exit 1; }
		native_build
		;;
	docker)
		command -v docker >/dev/null 2>&1 || { echo "Docker not found. Install Docker, or use the GitHub Actions workflow." >&2; exit 1; }
		# Build in the container's own filesystem (bind mounts on Windows/macOS break
		# permissions and symlinks inside the chroot), then copy the results back.
		docker run --rm --privileged -v "$PWD":/out debian:trixie sh -c '
			set -eu
			apt-get update && apt-get install -y --no-install-recommends ca-certificates
			mkdir /build && cp -a /out/. /build/ && cd /build
			sh ./build.sh native-inner
			cp -v candy-linux-*.iso SHA256SUMS /out/
		'
		;;
	*)
		echo "usage: $0 [native|docker]" >&2
		exit 2
		;;
esac
