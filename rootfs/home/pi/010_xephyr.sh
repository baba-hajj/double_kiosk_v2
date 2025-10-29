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
# 1️⃣ Configure monitors with detection retry
# -----------------------------------------------------------

# Function to detect and configure displays
configure_displays() {
    local max_attempts=10
    local attempt=1
    local hdmi1_found=false
    local hdmi2_found=false

    echo "Detecting displays..."

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Checking for displays..."

        # Check if HDMI-1 is connected
        if DISPLAY=:0 xrandr | grep -q "^HDMI-1 connected"; then
            hdmi1_found=true
            echo "  ✓ HDMI-1 detected"
        else
            echo "  ✗ HDMI-1 not detected"
        fi

        # Check if HDMI-2 is connected
        if DISPLAY=:0 xrandr | grep -q "^HDMI-2 connected"; then
            hdmi2_found=true
            echo "  ✓ HDMI-2 detected"
        else
            echo "  ✗ HDMI-2 not detected"
        fi

        # If both displays found, configure them
        if [ "$hdmi1_found" = true ] && [ "$hdmi2_found" = true ]; then
            echo "Both displays detected! Configuring..."

            # Configure HDMI-1 (primary, left screen)
            DISPLAY=:0 xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --rotate "$ORIENTATION" --primary
            sleep 1

            # Configure HDMI-2 (secondary, right screen)
            DISPLAY=:0 xrandr --output HDMI-2 --mode 1920x1080 --pos 1920x0 --rotate "$ORIENTATION"
            sleep 1

            echo "Display configuration complete"
            return 0
        fi

        # If not found, wait and retry
        echo "Waiting for displays... (${attempt}s)"
        sleep 2
        attempt=$((attempt + 1))
    done

    # If we get here, one or both displays weren't detected
    echo "WARNING: Display detection incomplete after $max_attempts attempts"
    echo "  HDMI-1: $hdmi1_found"
    echo "  HDMI-2: $hdmi2_found"

    # Try to configure whatever we found
    if [ "$hdmi1_found" = true ]; then
        echo "Configuring HDMI-1 only..."
        DISPLAY=:0 xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --rotate "$ORIENTATION" --primary
    fi

    if [ "$hdmi2_found" = true ]; then
        echo "Configuring HDMI-2 only..."
        DISPLAY=:0 xrandr --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate "$ORIENTATION" --primary
    fi

    return 1
}

# Run display configuration
configure_displays

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

# -----------------------------------------------------------
# Hide all mouse cursors for touch-only kiosk experience
# -----------------------------------------------------------
echo "Hiding mouse cursors..."

# Method 1: Use unclutter to hide cursor (install if not present)
if command -v unclutter &> /dev/null; then
    DISPLAY=:0 unclutter -idle 0.01 -root &
    echo "  ✓ unclutter started (cursor hidden)"
else
    echo "  ⚠ unclutter not installed, trying alternative method"
fi

# Method 2: Set root window cursor to blank
DISPLAY=:0 xsetroot -cursor_name none 2>/dev/null || true

# Method 3: Hide cursor in Chromium (added via flags below)
echo "Cursor hiding configured"

# Launch Chromium browsers directly on host X server
# Browser 1: Left screen (starts at x=0)
# Performance optimized with GPU acceleration, memory management, and kiosk flags
DISPLAY=:0 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-1 \
  --window-position=0,0 \
  --window-size="$SCR_W","$CHR_H" \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --load-extension=/home/pi/kiosk-autofill-extension \
  --app="$URL_01" \
  --enable-gpu-rasterization \
  --enable-zero-copy \
  --enable-hardware-overlays \
  --use-gl=egl \
  --use-angle=gles \
  --disable-software-rasterizer \
  --enable-gpu-compositing \
  --enable-smooth-scrolling \
  --enable-native-gpu-memory-buffers \
  --js-flags="--max-old-space-size=256" \
  --memory-model=low \
  --aggressive-tab-discarding \
  --renderer-process-limit=2 \
  --disable-background-timer-throttling \
  --max-tiles-for-interest-area=512 \
  --disk-cache-size=104857600 \
  --enable-dns-prefetch \
  --enable-async-dns \
  --disable-background-networking \
  --disable-component-update \
  --disable-crash-reporter \
  --disable-breakpad \
  --disable-sync \
  --disable-translate \
  --disable-features=TranslateUI \
  --disable-default-apps \
  --disable-dev-tools \
  --autoplay-policy=no-user-gesture-required \
  --no-first-run \
  --no-default-browser-check \
  --disable-session-crashed-bubble \
  --disable-restore-session-state \
  --kiosk-printing \
  --enable-features=OverlayScrollbar \
  --hide-scrollbars &

sleep 2

# Browser 2: Right screen (starts at x=1920 for landscape, adjusts for portrait)
if [[ "$ORIENTATION" == "normal" || "$ORIENTATION" == "inverted" ]]; then
    WINDOW_X=1920
else
    WINDOW_X=1080
fi

# Performance optimized with GPU acceleration, memory management, and kiosk flags
DISPLAY=:0 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-2 \
  --window-position="$WINDOW_X",0 \
  --window-size="$SCR_W","$CHR_H" \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --load-extension=/home/pi/kiosk-autofill-extension \
  --app="$URL_02" \
  --enable-gpu-rasterization \
  --enable-zero-copy \
  --enable-hardware-overlays \
  --use-gl=egl \
  --use-angle=gles \
  --disable-software-rasterizer \
  --enable-gpu-compositing \
  --enable-smooth-scrolling \
  --enable-native-gpu-memory-buffers \
  --js-flags="--max-old-space-size=256" \
  --memory-model=low \
  --aggressive-tab-discarding \
  --renderer-process-limit=2 \
  --disable-background-timer-throttling \
  --max-tiles-for-interest-area=512 \
  --disk-cache-size=104857600 \
  --enable-dns-prefetch \
  --enable-async-dns \
  --disable-background-networking \
  --disable-component-update \
  --disable-crash-reporter \
  --disable-breakpad \
  --disable-sync \
  --disable-translate \
  --disable-features=TranslateUI \
  --disable-default-apps \
  --disable-dev-tools \
  --autoplay-policy=no-user-gesture-required \
  --no-first-run \
  --no-default-browser-check \
  --disable-session-crashed-bubble \
  --disable-restore-session-state \
  --kiosk-printing \
  --enable-features=OverlayScrollbar \
  --hide-scrollbars &

sleep 3

# Configure keyboard focus for MPX compatibility
# Ensures Chromium windows accept keyboard input from Virtual core keyboard
echo "Configuring keyboard input for browsers..."

# Find all Chromium windows
CHROMIUM_WINDOWS=$(DISPLAY=:0 xdotool search --sync --onlyvisible --class "Chromium" 2>/dev/null || echo "")

if [ -n "$CHROMIUM_WINDOWS" ]; then
    for window_id in $CHROMIUM_WINDOWS; do
        # Set client pointer to Virtual core pointer (id=2) for each window
        # This ensures the window accepts input from Virtual core keyboard
        DISPLAY=:0 xinput set-client-pointer "$window_id" 2 2>/dev/null || true

        # Give window focus
        DISPLAY=:0 xdotool windowfocus --sync "$window_id" 2>/dev/null || true
    done
    echo "Configured keyboard input for $(echo "$CHROMIUM_WINDOWS" | wc -w) browser window(s)"
else
    echo "Warning: No Chromium windows found yet"
fi

wait
