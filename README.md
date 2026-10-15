# Candy Linux

A Debian 13 ("trixie") live and installable ISO build kit tuned for the **Dell Chromebook 11 (3120), codename "candy"**: Celeron N2830/N2840 (Bay Trail-M), 2 or 4 GB RAM, 16 GB eMMC, Intel Wi-Fi AC 7260.

> **Model number:** Dell's model is **3120**, not 3210. The codename `candy` is what firmware and Linux tooling use.

## Status: read this first

- This kit has **not been built into an ISO or booted on a real candy yet.** Its shell scripts and workflow were syntax-checked, but the first real test is the first CI build and the first boot on your laptop.
- Every candy-specific setting below comes from published reports about this laptop (see [docs/HARDWARE.md](docs/HARDWARE.md)). Expect to adjust a few things after the first boot; `candy-diag` is there to make that quick.
- Flashing firmware (Step 1) can brick a Chromebook if interrupted. Do it with the charger connected and a stock-firmware backup.

## What it changes for the candy

| Area | What Candy Linux does | Where |
|---|---|---|
| Keyboard | xkb `chromebook` model: right Alt acts as a modifier for F1-F10, Page Up/Down, Caps Lock, Delete. Alt+Shift switches US / Arabic. The installer's generic keyboard model is corrected on first boot. | `etc/default/keyboard`, `usr/local/lib/candy/firstboot.sh` |
| Audio | DSP firmware (`firmware-intel-sound`, SOF as fallback), `alsa-ucm-conf` (has the `chtmax98090` profile), PipeWire | `package-lists/`, `hooks/live/0020-*` |
| Wi-Fi / Bluetooth | `firmware-iwlwifi` for the Intel 7260, plus Intel Bluetooth firmware | `package-lists/`, `hooks/live/0020-*` |
| Touchpad | libinput: tap-to-click, disable-while-typing, two-finger click for right-click | `etc/X11/xorg.conf.d/40-candy-touchpad.conf` |
| Suspend | Disables the touchpad/touchscreen ACPI wake source, so a closed lid pressing the pad doesn't wake the laptop | `candy-touchpad-wakeup.service` |
| Power button | Short press ignored, long press powers off | `etc/systemd/logind.conf.d/candy.conf` |
| Memory | zram swap (zstd), tuned sysctls | `etc/systemd/zram-generator.conf`, `etc/sysctl.d/90-candy.conf` |
| eMMC wear | `noatime`, weekly TRIM, journal capped at 50 MB, lazy writeback | `firstboot.sh`, `etc/systemd/journald.conf.d/` |
| Battery | TLP with Wi-Fi and runtime power management on battery | `etc/tlp.d/10-candy.conf` |
| Desktop | XFCE, kept light for 2-4 GB RAM; Firefox ESR; Calamares installer | `package-lists/candy.list.chroot` |
| Debugging | `sudo candy-diag` writes a full hardware report | `usr/local/bin/candy-diag` |

Defaults you may want to change: timezone `Asia/Baghdad` and the extra Arabic keyboard layout (both in `auto/config`), tap-to-click and scroll direction (`40-candy-touchpad.conf`).

## Step 1: Firmware (one-time)

Stock Chromebook firmware boots poorly from USB. The candy is supported by MrChromebox's **UEFI Full ROM** firmware, which makes it behave like a normal PC. Write protection on this board is a **screw** on the motherboard, which must be removed before a Full ROM flash.

1. Put the Chromebook in Developer Mode (this erases ChromeOS data). Follow the MrChromebox docs for the exact key sequence.
2. Open the case and remove the firmware write-protect screw. The MrChromebox docs have a "Firmware Write Protect" page that explains it; look up CANDY in [Supported Devices](https://docs.mrchromebox.tech/docs/supported-devices.html) to confirm the WP method.
3. In ChromeOS, open a shell (Ctrl+Alt+T, then `shell`) and run:
   ```
   cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
   ```
4. Let the script back up the stock firmware to a USB stick, then choose **Install/Update UEFI (Full ROM) Firmware**.

Check [Supported Devices](https://docs.mrchromebox.tech/docs/supported-devices.html) for the current status of CANDY before you start.

## Step 2: Get the ISO

### Option A: GitHub Actions (no Linux machine needed)

1. Create a new GitHub repository and upload the contents of this folder.
2. Open the **Actions** tab, pick **Build Candy Linux ISO**, and click **Run workflow**.
3. When it finishes (roughly 20-40 minutes), download the `candy-linux-iso` artifact. Unzip it to get the `.iso` and `SHA256SUMS`.

If the build fails, download the `build-log` artifact. The most likely cause is a package name that doesn't exist; the build checks for that first and prints the exact names to remove from `config/package-lists/candy.list.chroot`.

### Option B: Build locally

```
./build.sh          # Debian host as root builds natively; anything else uses Docker
```

Requires Docker, or a Debian machine running as root, plus about 10 GB of free disk space.

## Step 3: Write the ISO to a USB stick

Use balenaEtcher, Rufus (choose **DD image mode**), or on Linux:

```
sudo dd if=candy-linux-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Optional: run `tools/test-qemu.sh` first to confirm the ISO boots in a VM.

## Step 4: Boot and install

1. Plug in the USB stick, power on, and press **Esc** at the boot logo to open the boot menu (see the MrChromebox docs if your firmware version differs). Choose the USB stick.
2. The live desktop starts automatically. Wi-Fi, sound, the touchpad and the keyboard should work from the live session; run `sudo candy-diag` if any don't.
3. Double-click **Install Candy Linux** on the desktop. On the 16 GB eMMC choose *Erase disk* with ext4. **No swap partition**: zram handles swap.

## Already have Linux installed?

Apply only the tuning to your existing Debian/Ubuntu-based install:

```
sudo tools/candy-apply.sh --dry-run   # preview
sudo tools/candy-apply.sh
```

## Troubleshooting

- **No sound.** Run `sudo candy-diag` and look at the Audio section. You should see a card named `chtmax98090` (or `sof-bytcht max98090` on the SOF driver). If the card exists but is silent, open `pavucontrol` and check the output profile. If there's no card at all, look for firmware errors at the bottom of the report. As an experiment you can force the other driver with a kernel parameter, `snd_intel_dspcfg.dsp_driver=2` (legacy SST) or `=3` (SOF), but this is untested on the candy.
- **Random freezes.** Some Bay Trail systems freeze in deep CPU idle states. The workaround is the kernel parameter `intel_idle.max_cstate=1`. At the boot menu press `e`, add it to the `linux` line, and press Ctrl+X. To make it permanent after installing, add it to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` and run `sudo update-grub`.
- **Laptop wakes up when the lid is closed.** `cat /proc/acpi/wakeup`: TPAD and TSCR should say `disabled`. If another device is the culprit, toggle it with `echo NAME | sudo tee /proc/acpi/wakeup`.
- **Keyboard top row.** The row sends browser/media keys (back, forward, reload, brightness, volume). Hold right Alt for F1-F10.
- **Scroll direction or tapping.** Edit `/etc/X11/xorg.conf.d/40-candy-touchpad.conf`, or use XFCE's Mouse and Touchpad settings.

## Customising

- Add or remove packages: `config/package-lists/candy.list.chroot` (run `tools/check-packages.sh` to validate).
- Change locale, timezone, hostname, keyboard: the `--bootappend-live` line in `auto/config`.
- Add any file to the image: place it under `config/includes.chroot_after_packages/` at its target path.
- Add build-time steps: scripts named `NNNN-name.hook.chroot` in `config/hooks/live/`.

## Layout

```
auto/                 live-build entry points (config holds all build options)
config/package-lists/ what gets installed
config/hooks/live/    build-time scripts (locale, firmware extras, installer, services)
config/includes.chroot_after_packages/   files copied into the image as-is
tools/                candy-apply.sh, check-packages.sh, test-qemu.sh
docs/HARDWARE.md      component-by-component driver notes
.github/workflows/    CI build
build.sh              local build wrapper
```
