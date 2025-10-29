#!/bin/bash
# Auto-start script for dual-kiosk system
# This file should be placed at /home/pi/.profile
# It will automatically start the kiosk when user 'pi' logs in to console

# Only run on tty1 (console login, not SSH)
if [ "$(tty)" = "/dev/tty1" ]; then
    echo "Starting Dual-Kiosk System..."

    # Start X server with kiosk script
    startx /home/pi/010_xephyr.sh -- :0 vt1

    # Alternative method (if startx doesn't work):
    # exec xinit /home/pi/010_xephyr.sh -- :0 vt1
fi
