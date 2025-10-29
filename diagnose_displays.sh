#!/bin/bash
# Display Diagnostic Script
# Run this on the Raspberry Pi with: DISPLAY=:0 bash diagnose_displays.sh

echo "=========================================="
echo "DISPLAY DIAGNOSTIC REPORT"
echo "=========================================="
echo ""

echo "1. XRANDR OUTPUT (Connected Displays):"
echo "-------------------"
DISPLAY=:0 xrandr 2>&1
echo ""

echo "2. XRANDR VERBOSE (Detailed Info):"
echo "-------------------"
DISPLAY=:0 xrandr --verbose 2>&1 | head -100
echo ""

echo "3. FRAMEBUFFER DEVICES:"
echo "-------------------"
ls -la /dev/fb* 2>&1
echo ""

echo "4. DRM DEVICES:"
echo "-------------------"
ls -la /sys/class/drm/ 2>&1
echo ""

echo "5. HDMI STATUS (via tvservice):"
echo "-------------------"
if command -v tvservice &> /dev/null; then
    echo "HDMI-1 status:"
    tvservice -s -v 2 2>&1 || echo "  tvservice not available for HDMI-1"
    echo ""
    echo "HDMI-2 status:"
    tvservice -s -v 7 2>&1 || echo "  tvservice not available for HDMI-2"
else
    echo "tvservice command not available"
fi
echo ""

echo "6. KMS/DRM CARD INFO:"
echo "-------------------"
if [ -e /sys/class/drm/card1-HDMI-A-1/status ]; then
    echo "HDMI-1 status: $(cat /sys/class/drm/card1-HDMI-A-1/status 2>&1)"
else
    echo "HDMI-1 status file not found"
fi

if [ -e /sys/class/drm/card1-HDMI-A-2/status ]; then
    echo "HDMI-2 status: $(cat /sys/class/drm/card1-HDMI-A-2/status 2>&1)"
else
    echo "HDMI-2 status file not found"
fi
echo ""

echo "7. DISPLAY ENVIRONMENT:"
echo "-------------------"
echo "DISPLAY variable: $DISPLAY"
echo "X server running: $(pgrep -a X | head -1 || echo 'Not found')"
echo ""

echo "8. BOOT CONFIG (HDMI settings):"
echo "-------------------"
grep -i hdmi /boot/firmware/config.txt 2>&1 | grep -v "^#" || echo "No HDMI config found"
echo ""

echo "9. CURRENT DISPLAY RESOLUTION:"
echo "-------------------"
DISPLAY=:0 xdpyinfo 2>&1 | grep dimensions
echo ""

echo "10. TOUCHSCREEN MAPPING STATUS:"
echo "-------------------"
echo "Touch devices and their mappings:"
DISPLAY=:0 xinput list | grep -i "Weida\|Touch"
echo ""
for id in $(DISPLAY=:0 xinput list | grep -i "Weida.*CoolTouchR System" | grep -v Mouse | grep -oP 'id=\K\d+'); do
    echo "Device $id coordinate transformation:"
    DISPLAY=:0 xinput list-props "$id" | grep "Coordinate Transformation Matrix"
done
echo ""

echo "11. WINDOW POSITIONS:"
echo "-------------------"
CHROMIUM_WINDOWS=$(DISPLAY=:0 xdotool search --class "Chromium" 2>/dev/null || echo "")
if [ -n "$CHROMIUM_WINDOWS" ]; then
    for win in $CHROMIUM_WINDOWS; do
        echo "Chromium window $win:"
        DISPLAY=:0 xdotool getwindowgeometry "$win" 2>&1
        echo ""
    done
else
    echo "No Chromium windows found"
fi
echo ""

echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="
echo ""
echo "KEY THINGS TO CHECK:"
echo "1. Are both HDMI-1 and HDMI-2 showing as 'connected' in xrandr?"
echo "2. What are the resolutions for each display?"
echo "3. What are the coordinate transformation matrices for touch devices?"
echo "4. Are Chromium windows positioned correctly?"
echo ""
echo "Save this output and share for analysis"
