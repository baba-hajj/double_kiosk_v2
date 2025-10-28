#!/usr/bin/env bash
################################################################################
# Touchscreen Mapping Test Tool
# Purpose: Manually test touchscreen-to-display mapping
# Usage: ./test-touchscreen-mapping.sh <device_id_1> <device_id_2>
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

show_usage() {
    echo "Usage: $0 <device_id_1> <device_id_2>"
    echo ""
    echo "Maps:"
    echo "  device_id_1 → HDMI-1 (Primary/Left)"
    echo "  device_id_2 → HDMI-2 (Secondary/Right)"
    echo ""
    echo "Example:"
    echo "  $0 7 8"
    echo ""
    echo "To find device IDs, run: xinput list | grep -i touch"
    echo "Or run the diagnostic script: ./bin/diagnose-touchscreens.sh"
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    show_usage
fi

DEVICE_1=$1
DEVICE_2=$2

# Validate device IDs are numbers
if ! [[ "$DEVICE_1" =~ ^[0-9]+$ ]] || ! [[ "$DEVICE_2" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Device IDs must be numbers${RESET}"
    show_usage
fi

echo -e "${BOLD}${BLUE}Touchscreen Mapping Test${RESET}"
echo -e "═══════════════════════════════════════════════════════════════════════\n"

# Check if devices exist
echo -e "${BOLD}Checking devices...${RESET}\n"

if ! xinput list "$DEVICE_1" &>/dev/null; then
    echo -e "${RED}✗${RESET} Device $DEVICE_1 not found"
    echo "Available devices:"
    xinput list
    exit 1
else
    NAME_1=$(xinput list --name-only "$DEVICE_1")
    echo -e "${GREEN}✓${RESET} Device $DEVICE_1: $NAME_1"
fi

if ! xinput list "$DEVICE_2" &>/dev/null; then
    echo -e "${RED}✗${RESET} Device $DEVICE_2 not found"
    echo "Available devices:"
    xinput list
    exit 1
else
    NAME_2=$(xinput list --name-only "$DEVICE_2")
    echo -e "${GREEN}✓${RESET} Device $DEVICE_2: $NAME_2"
fi

echo ""

# Check displays
echo -e "${BOLD}Checking displays...${RESET}\n"

if ! xrandr | grep -q "HDMI-1 connected"; then
    echo -e "${RED}✗${RESET} HDMI-1 not connected"
    xrandr
    exit 1
else
    echo -e "${GREEN}✓${RESET} HDMI-1 connected"
fi

if ! xrandr | grep -q "HDMI-2 connected"; then
    echo -e "${RED}✗${RESET} HDMI-2 not connected"
    xrandr
    exit 1
else
    echo -e "${GREEN}✓${RESET} HDMI-2 connected"
fi

echo ""

# Apply mapping
echo -e "${BOLD}Applying mapping...${RESET}\n"

echo -e "  ${BLUE}→${RESET} Mapping device $DEVICE_1 to HDMI-1..."
if xinput map-to-output "$DEVICE_1" HDMI-1; then
    echo -e "    ${GREEN}✓${RESET} Success"
else
    echo -e "    ${RED}✗${RESET} Failed"
    exit 1
fi

echo -e "  ${BLUE}→${RESET} Mapping device $DEVICE_2 to HDMI-2..."
if xinput map-to-output "$DEVICE_2" HDMI-2; then
    echo -e "    ${GREEN}✓${RESET} Success"
else
    echo -e "    ${RED}✗${RESET} Failed"
    exit 1
fi

echo ""

# Verify mapping
echo -e "${BOLD}Verifying mapping...${RESET}\n"

MATRIX_1=$(xinput list-props "$DEVICE_1" | grep "Coordinate Transformation Matrix" | grep -oP ':\s+\K.*' || echo "")
MATRIX_2=$(xinput list-props "$DEVICE_2" | grep "Coordinate Transformation Matrix" | grep -oP ':\s+\K.*' || echo "")

if [ -n "$MATRIX_1" ]; then
    echo -e "${GREEN}✓${RESET} Device $DEVICE_1 has transformation matrix"
    echo -e "  Matrix: $MATRIX_1"
else
    echo -e "${YELLOW}⚠${RESET} Device $DEVICE_1 has no transformation matrix"
fi

if [ -n "$MATRIX_2" ]; then
    echo -e "${GREEN}✓${RESET} Device $DEVICE_2 has transformation matrix"
    echo -e "  Matrix: $MATRIX_2"
else
    echo -e "${YELLOW}⚠${RESET} Device $DEVICE_2 has no transformation matrix"
fi

echo ""
echo -e "═══════════════════════════════════════════════════════════════════════"
echo -e "${BOLD}${GREEN}Mapping applied successfully!${RESET}\n"

echo -e "${BOLD}Testing instructions:${RESET}"
echo -e "  1. Touch the ${BOLD}LEFT${RESET} screen"
echo -e "     → Cursor should move on the ${BOLD}LEFT${RESET} display"
echo -e ""
echo -e "  2. Touch the ${BOLD}RIGHT${RESET} screen"
echo -e "     → Cursor should move on the ${BOLD}RIGHT${RESET} display"
echo -e ""
echo -e "${YELLOW}Note:${RESET} This mapping is temporary and will reset on reboot."
echo -e "      If it works correctly, we'll add it to the permanent configuration."
echo -e ""

# Offer to monitor touch events
echo -e "${BOLD}Want to monitor touch events?${RESET}"
echo -e "Run these commands in separate terminals:"
echo -e "  ${CYAN}xinput test $DEVICE_1${RESET}  # Monitor device $DEVICE_1"
echo -e "  ${CYAN}xinput test $DEVICE_2${RESET}  # Monitor device $DEVICE_2"
echo -e ""
echo -e "Then touch each screen to see which device responds."
echo ""
