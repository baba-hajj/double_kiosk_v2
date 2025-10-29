#!/bin/bash
# Keyboard Diagnostic Script
# Run this on the Raspberry Pi with: DISPLAY=:0 bash diagnose_keyboard.sh

echo "=========================================="
echo "KEYBOARD DIAGNOSTIC REPORT"
echo "=========================================="
echo ""

echo "1. ALL INPUT DEVICES:"
echo "-------------------"
DISPLAY=:0 xinput list
echo ""

echo "2. MASTER DEVICES (Pointers and Keyboards):"
echo "-------------------"
DISPLAY=:0 xinput list | grep -E "master|slave"
echo ""

echo "3. PHYSICAL KEYBOARD DEVICES:"
echo "-------------------"
DISPLAY=:0 xinput list | grep -i keyboard | grep -v "pointer"
echo ""

echo "4. CHECKING WHICH KEYBOARD IS ATTACHED WHERE:"
echo "-------------------"
# Get all keyboard device IDs
KEYBOARD_IDS=$(DISPLAY=:0 xinput list | grep -i keyboard | grep -v "pointer" | grep -oP 'id=\K\d+')

for id in $KEYBOARD_IDS; do
    name=$(DISPLAY=:0 xinput list --name-only "$id")
    echo "Device $id: $name"

    # Check if it's a slave or master
    device_type=$(DISPLAY=:0 xinput list | grep "id=$id" | grep -oP '(slave|master)\s+\w+')
    echo "  Type: $device_type"

    # If slave, show which master it's attached to
    if echo "$device_type" | grep -q "slave"; then
        master=$(DISPLAY=:0 xinput list | grep "id=$id" -A 1 | grep "Attached to" || echo "  Attached to: (checking...)")
        echo "  $master"
    fi
    echo ""
done

echo "5. ACTIVE WINDOW FOCUS:"
echo "-------------------"
ACTIVE_WINDOW=$(DISPLAY=:0 xdotool getactivewindow 2>/dev/null)
if [ -n "$ACTIVE_WINDOW" ]; then
    echo "Active window ID: $ACTIVE_WINDOW"
    DISPLAY=:0 xdotool getwindowname "$ACTIVE_WINDOW" 2>/dev/null || echo "(unable to get window name)"
else
    echo "No active window detected"
fi
echo ""

echo "6. CHROMIUM PROCESSES:"
echo "-------------------"
ps aux | grep chromium | grep -v grep | head -2
echo ""

echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="
echo ""
echo "INSTRUCTIONS:"
echo "1. Review which master device your physical keyboard is attached to"
echo "2. Check if 'Virtual core keyboard' or 'Kiosk1/Kiosk2 keyboard' has the USB keyboard"
echo "3. Test: Click in one of the Chromium windows and try typing"
echo "4. Share this output for analysis"
