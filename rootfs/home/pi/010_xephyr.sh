#!/usr/bin/env bash
# Runs inside Xorg (DISPLAY=:0)

# Include configuration file
# Imported variables:
# URL_01          - URL for the first browser
# URL_02          - URL for the second browser
# ORIENTATION     - Monitor orientation
# TOUCHSCREEN_PATTERN - Touchscreen device pattern
source /boot/firmware/kiosk_config.sh


if [[ "$ORIENTATION" == "normal" || "$ORIENTATION" == "inverted" ]]; then
    SCR_W=1920
    SCR_H=1080
elif [[ "$ORIENTATION" == "left" || "$ORIENTATION" == "right" ]]; then
    SCR_W=1080
    SCR_H=1920
fi

# SCR_W=1920
# SCR_H=1080

# Chromium will use full screen height (no on-screen keyboard)
CHR_H=$SCR_H

# Wait a bit for GPU driver to settle
sleep 2

# -----------------------------------------------------------
# 1️⃣ Configure monitors
# -----------------------------------------------------------
xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --rotate "$ORIENTATION" --primary
xrandr --output HDMI-2 --mode 1920x1080 --pos 1920x0 --rotate "$ORIENTATION"

# -----------------------------------------------------------
# 1️⃣ Configure touchscreen inputs with Multi-Pointer X (MPX)
# -----------------------------------------------------------

# Source touchscreen setup library
if [ -f "$HOME/lib/logging.sh" ] && [ -f "$HOME/lib/touchscreen-setup.sh" ]; then
    source "$HOME/lib/logging.sh"
    source "$HOME/lib/touchscreen-setup.sh"

    # Initialize logging
    init_logging

    # Run MPX touchscreen setup
    log_info "Starting touchscreen configuration..."
    if setup_touchscreens_mpx; then
        log_info "Touchscreen configuration successful"
    else
        log_error "Touchscreen MPX setup failed, attempting fallback..."
        if fallback_simple_mapping; then
            log_warn "Using fallback mapping - independent cursors NOT available"
        else
            log_error "All touchscreen configuration attempts failed!"
            # Continue anyway - system might still be usable with keyboard/mouse
        fi
    fi
else
    # Fallback to old method if libraries not found
    echo "WARNING: Touchscreen libraries not found, using legacy configuration" >&2
    TEXT=$(DISPLAY=:0 xinput list | grep "$TOUCHSCREEN_PATTERN")
    TOUCHSCREEN_LINES=$(echo "$TEXT" | grep "$TOUCHSCREEN_PATTERN")
    IDS=$(echo "$TOUCHSCREEN_LINES" | grep -o 'id=[0-9]\+' | cut -d= -f2 | paste -sd' ' -)
    OUTPUTS="HDMI-1 HDMI-2"
    IDS_ARR=($IDS)
    OUTS_ARR=($OUTPUTS)
    for i in "${!IDS_ARR[@]}"; do
        ID="${IDS_ARR[$i]}"
        OUTPUT="${OUTS_ARR[$i]}"
        xinput map-to-output "$ID" "$OUTPUT"
    done
fi

# Start OpenBox window manager on host X server
DISPLAY=:0 openbox-session --config-file /etc/xdg/openbox/rc.xml &

sleep 2

# Launch Chromium browsers directly on host X server
# Browser 1: Left screen (starts at x=0)
DISPLAY=:0 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-1 \
  --window-position=0,0 \
  --window-size="$SCR_W","$CHR_H" \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --load-extension=/home/pi/kiosk-autofill-extension \
  --app="$URL_01" &

sleep 2

# Browser 2: Right screen (starts at x=1920 for landscape, adjusts for portrait)
if [[ "$ORIENTATION" == "normal" || "$ORIENTATION" == "inverted" ]]; then
    WINDOW_X=1920
else
    WINDOW_X=1080
fi

DISPLAY=:0 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-2 \
  --window-position="$WINDOW_X",0 \
  --window-size="$SCR_W","$CHR_H" \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --load-extension=/home/pi/kiosk-autofill-extension \
  --app="$URL_02" &

wait
