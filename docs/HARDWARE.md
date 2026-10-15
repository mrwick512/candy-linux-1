# Dell Chromebook 11 (3120) "candy": hardware and driver notes

Confidence key: **documented** = stated by a source listed at the bottom; **from specs** = follows from the chip named in the specs, but not confirmed on this laptop under Linux; **unverified** = a reasonable expectation only.

| Component | Hardware | Linux side | Provided by | Confidence |
|---|---|---|---|---|
| CPU | Intel Celeron N2840 (some units N2830), Bay Trail-M, 2 cores | `intel_pstate`, `intel_idle` | kernel | documented |
| RAM | 2 or 4 GB DDR3L | zram swap | `systemd-zram-generator` | documented |
| Storage | 16 GB eMMC (some 32 GB) | `mmcblk0`, health via `mmc extcsd read` | kernel, `mmc-utils` | from specs |
| Graphics | Intel HD Graphics (Bay Trail) | `i915` + Mesa, VA-API via `i965-va-driver` | kernel, `libgl1-mesa-dri` | from specs |
| Display | 11.6" 1366x768, TN or IPS, touch on some models | plain X11 modesetting | `xserver-xorg-core` | documented |
| Wi-Fi | Intel Dual Band Wireless-AC 7260 | `iwlwifi` | `firmware-iwlwifi` | documented |
| Bluetooth | Bluetooth 4.0 (on the 7260) | `btusb` + Intel firmware | `firmware-intel-misc` or `firmware-misc-nonfree` | from specs |
| Audio | MAX98090 codec, card `chtmax98090` | SST DSP + ASoC machine driver, UCM profile | `firmware-intel-sound`, `alsa-ucm-conf`, PipeWire | documented |
| Touchpad | ClickPad (no separate buttons) | libinput; the kernel driver (Cypress, Elan, Atmel) is not confirmed | `xserver-xorg-input-libinput` | from specs |
| Keyboard | Chromebook layout (no Caps Lock, Delete, F-keys, Page keys) | xkb model `chromebook` | `keyboard-configuration`, `etc/default/keyboard` | documented |
| Webcam | HD webcam | `uvcvideo` | kernel | unverified |
| SD card reader | SD slot (cards don't seat fully) | `mmc` / `sdhci` | kernel | from specs |
| LED light bar | USB HID device `04d8:0b28` | a small Python script writing to `/dev/hidraw*` | not included | documented (blog) |
| Firmware | coreboot; MrChromebox UEFI Full ROM supported; write protect is a screw | | MrChromebox | documented |

## Notes

- The Wi-Fi chip is called out in one review's spec sheet. If your unit has a different card, `candy-diag` shows it under "Wi-Fi and Bluetooth"; add the matching `firmware-*` package.
- Audio on Bay Trail Chromebooks is a known pain point, and reports vary by kernel and firmware. Upstream `alsa-ucm-conf` ships a `chtmax98090` profile (it is listed in its `ucm2/conf.d` directory), so none is bundled here and Debian's package should carry it. `candy-diag` lists the Cherry/Bay Trail profiles actually installed; if `chtmax98090` is missing, fall back to what an older (2018) guide for this laptop did: copy the `chtmax98090` folder from `plbossart/UCM` into `/usr/share/alsa/ucm`.
- The 2018 guide also found that a closed lid can press the touchpad and wake the machine; `candy-touchpad-wakeup.service` applies its fix generically for `TPAD` and `TSCR`.
- Bay Trail/Cherry Trail devices have a history of freezes in deep C-states. No candy-specific report was found, so the workaround (`intel_idle.max_cstate=1`) is documented in the README rather than enabled by default.

## Sources

- MrChromebox, Supported Devices: https://docs.mrchromebox.tech/docs/supported-devices.html
- iFixit (offline mirror), Dell Chromebook 11-3120, codename "Candy": https://kiwix.colibox.colibris-outilslibres.org/ifixit_fr_all_2022-08/C/Device/Dell_Chromebook_11-3120
- Notebookcheck, Dell Chromebook 11 (3120) review: https://www.notebookcheck.net/Dell-Chromebook-11-3120-Review.147301.0.html
- "Linux on Dell Chromebook 11" (2018): https://blog.nanax.fr/post/2018-05-01-chromebook-linux/
- chrultrabook forum, candy thread: https://forum.chrultrabook.com/t/dell-chromebook-11-3120-candy-running-windows-11-with-fully-functional-coolstar-drivers/8818
- chrultrabook forum, Bay Trail audio discussion: https://forum.chrultrabook.com/t/i-need-help-sorting-sound-on-my-linux-mint-on-chromebook-board-name-akali360/5897
