#!/bin/sh
# Live session only (the unit that runs this is skipped on an installed system).
#
# live-config creates the autologin user at boot, but nothing documents the
# password it gets, and XFCE shows the login screen after suspend. Set a known
# one. The account is whichever one live-config created: the first normal
# user, uid 1000 (named by the username= boot option, "candy" by default).
PASSWORD=live

i=0
user=""
while [ "$i" -lt 30 ]; do
	user=$(getent passwd 1000 | cut -d: -f1)
	[ -n "$user" ] && break
	i=$((i + 1))
	sleep 1
done

[ -n "$user" ] || exit 0
echo "$user:$PASSWORD" | chpasswd
exit 0
