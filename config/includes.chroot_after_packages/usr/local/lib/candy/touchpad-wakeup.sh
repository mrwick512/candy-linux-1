#!/bin/sh
# When the lid is closed the screen can press the touchpad, which wakes the
# laptop from suspend. Turn off the ACPI wake source for the pad (TPAD) and,
# on touch models, the touchscreen (TSCR). Writing a name to /proc/acpi/wakeup
# TOGGLES it, so only write when it is currently enabled.
WAKE=/proc/acpi/wakeup

[ -r "$WAKE" ] || exit 0

for dev in TPAD TSCR; do
	if grep -Eq "^${dev}[[:space:]].*\*enabled" "$WAKE"; then
		echo "$dev" > "$WAKE"
	fi
done

exit 0
