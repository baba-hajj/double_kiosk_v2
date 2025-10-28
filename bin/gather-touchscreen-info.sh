#!/usr/bin/env bash
################################################################################
# Simple touchscreen information gathering script
# Runs with minimal dependencies and saves output to file
################################################################################

OUTPUT_FILE="/tmp/touchscreen-info-$(date +%Y%m%d-%H%M%S).txt"

echo "Gathering touchscreen information..."
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

{
    echo "======================================================================"
    echo "TOUCHSCREEN INFORMATION REPORT"
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "======================================================================"
    echo ""

    echo "--- xinput list ---"
    DISPLAY=:0 xinput list 2>&1 || echo "ERROR: Could not run xinput list"
    echo ""

    echo "--- xinput list (devices 6-9 properties) ---"
    for id in 6 7 8 9; do
        echo ""
        echo "=== Device $id ==="
        DISPLAY=:0 xinput list-props $id 2>&1 || echo "ERROR: Could not get props for device $id"
    done
    echo ""

    echo "--- xrandr ---"
    DISPLAY=:0 xrandr 2>&1 || echo "ERROR: Could not run xrandr"
    echo ""

    echo "--- USB devices ---"
    lsusb -t 2>&1 || echo "ERROR: Could not run lsusb"
    echo ""

    echo "--- /dev/input devices ---"
    ls -la /dev/input/ 2>&1 || echo "ERROR: Could not list /dev/input"
    echo ""

    echo "--- /dev/input/by-path (if exists) ---"
    if [ -d /dev/input/by-path ]; then
        ls -la /dev/input/by-path/ 2>&1
    else
        echo "/dev/input/by-path does not exist"
    fi
    echo ""

    echo "--- /dev/input/by-id (if exists) ---"
    if [ -d /dev/input/by-id ]; then
        ls -la /dev/input/by-id/ 2>&1
    else
        echo "/dev/input/by-id does not exist"
    fi
    echo ""

    echo "======================================================================"
    echo "END OF REPORT"
    echo "======================================================================"

} > "$OUTPUT_FILE" 2>&1

echo "Information gathered successfully!"
echo "Report saved to: $OUTPUT_FILE"
echo ""
echo "Please share this file for analysis."
