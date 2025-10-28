#!/usr/bin/env bash
# Start one Xorg host and two Xephyr sub-sessions
xinit /home/pi/010_xephyr.sh -- :0 vt1

exit 0
