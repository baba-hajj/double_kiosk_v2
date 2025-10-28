#!/usr/bin/env bash
################################################################################
# Touchscreen Diagnostic Tool
# Purpose: Analyze touchscreen devices and provide mapping recommendations
# Usage: ./diagnose-touchscreens.sh [--json|--verbose]
################################################################################

set -euo pipefail

# Configuration
DISPLAY="${DISPLAY:-:0}"
TOUCHSCREEN_PATTERN="Weida Hi-Tech.*CoolTouchR System"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/touchscreen-diagnostic-$(date +%Y%m%d-%H%M%S).txt}"

# Colors for terminal output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' RESET=''
fi

# Parse arguments
VERBOSE=false
JSON_OUTPUT=false
for arg in "$@"; do
    case $arg in
        --verbose) VERBOSE=true ;;
        --json) JSON_OUTPUT=true ;;
        --help)
            echo "Usage: $0 [--json|--verbose|--help]"
            echo "  --json     Output in JSON format"
            echo "  --verbose  Show detailed debug information"
            echo "  --help     Show this help message"
            exit 0
            ;;
    esac
done

################################################################################
# Helper Functions
################################################################################

log_section() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}$1${RESET}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════${RESET}\n"
}

log_subsection() {
    echo -e "\n${BOLD}${BLUE}───────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}${BLUE}$1${RESET}"
    echo -e "${BOLD}${BLUE}───────────────────────────────────────────────────────────────────────${RESET}\n"
}

log_info() {
    echo -e "${GREEN}✓${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

log_error() {
    echo -e "${RED}✗${RESET} $1"
}

log_detail() {
    echo -e "  ${CYAN}→${RESET} $1"
}

################################################################################
# Device Detection Functions
################################################################################

get_all_xinput_ids() {
    xinput list | grep -E "$TOUCHSCREEN_PATTERN" | grep -oP 'id=\K\d+' || echo ""
}

get_device_name() {
    local id=$1
    xinput list --name-only "$id" 2>/dev/null || echo "Unknown"
}

get_device_node() {
    local id=$1
    xinput list-props "$id" 2>/dev/null | grep "Device Node" | grep -oP '"/dev/input/\K[^"]+' || echo ""
}

has_absolute_axes() {
    local id=$1
    xinput list-props "$id" 2>/dev/null | grep -q "Abs MT Position X" && return 0
    xinput list-props "$id" 2>/dev/null | grep -q "Abs X" && return 0
    return 1
}

has_coordinate_transformation() {
    local id=$1
    xinput list-props "$id" 2>/dev/null | grep -q "Coordinate Transformation Matrix" && return 0
    return 1
}

get_device_type() {
    local id=$1

    # Check if it's a touch device
    if has_absolute_axes "$id" && has_coordinate_transformation "$id"; then
        echo "TOUCH"
    elif xinput list-props "$id" 2>/dev/null | grep -q "Mouse"; then
        echo "MOUSE_EMULATION"
    else
        echo "UNKNOWN"
    fi
}

get_usb_port() {
    local device_node=$1
    if [ -z "$device_node" ]; then
        echo "N/A"
        return
    fi

    local full_path="/dev/input/$device_node"
    if [ ! -e "$full_path" ]; then
        echo "N/A"
        return
    fi

    # Get USB port from udevadm
    local usb_path=$(udevadm info --query=property --name="$full_path" 2>/dev/null |
                     grep "DEVPATH=" |
                     grep -oP 'usb\d+/\d+-\K[\d.]+' |
                     head -1)

    if [ -z "$usb_path" ]; then
        echo "N/A"
    else
        echo "$usb_path"
    fi
}

get_device_product_id() {
    local device_node=$1
    if [ -z "$device_node" ] || [ ! -e "/dev/input/$device_node" ]; then
        echo "N/A"
        return
    fi

    udevadm info --query=property --name="/dev/input/$device_node" 2>/dev/null |
        grep "ID_VENDOR_ID\|ID_MODEL_ID" |
        cut -d= -f2 |
        paste -sd':' - || echo "N/A"
}

is_device_enabled() {
    local id=$1
    local enabled=$(xinput list-props "$id" 2>/dev/null | grep "Device Enabled" | grep -oP '\d+$')
    [ "$enabled" = "1" ] && return 0
    return 1
}

################################################################################
# Display Detection Functions
################################################################################

get_connected_displays() {
    xrandr --query 2>/dev/null | grep " connected" | grep -oP '^\S+' || echo ""
}

get_display_resolution() {
    local display=$1
    xrandr --query 2>/dev/null | grep "^$display" | grep -oP '\d+x\d+' | head -1 || echo "Unknown"
}

get_display_position() {
    local display=$1
    xrandr --query 2>/dev/null | grep "^$display" | grep -oP '\+\d+\+\d+' | head -1 || echo "Unknown"
}

################################################################################
# Main Diagnostic Logic
################################################################################

main() {
    # Redirect all output to both terminal and file
    exec > >(tee "$OUTPUT_FILE")

    log_section "TOUCHSCREEN DIAGNOSTIC REPORT"
    echo -e "Generated: ${BOLD}$(date)${RESET}"
    echo -e "Hostname: ${BOLD}$(hostname)${RESET}"
    echo -e "User: ${BOLD}$(whoami)${RESET}"
    echo -e "Display: ${BOLD}$DISPLAY${RESET}"
    echo ""

    # Check prerequisites
    log_section "1. SYSTEM CHECKS"

    if ! command -v xinput &> /dev/null; then
        log_error "xinput command not found"
        exit 1
    else
        log_info "xinput available: $(xinput --version 2>&1 | head -1)"
    fi

    if ! command -v xrandr &> /dev/null; then
        log_error "xrandr command not found"
        exit 1
    else
        log_info "xrandr available"
    fi

    if ! xdpyinfo &> /dev/null; then
        log_error "Cannot connect to X display $DISPLAY"
        exit 1
    else
        log_info "X display $DISPLAY is accessible"
    fi

    if ! command -v udevadm &> /dev/null; then
        log_warn "udevadm not available (USB detection limited)"
    else
        log_info "udevadm available"
    fi

    # Detect displays
    log_section "2. DISPLAY CONFIGURATION"

    displays=$(get_connected_displays)
    display_count=$(echo "$displays" | wc -w)

    log_info "Found $display_count connected display(s)"
    echo ""

    for display in $displays; do
        resolution=$(get_display_resolution "$display")
        position=$(get_display_position "$display")
        log_detail "Display: ${BOLD}$display${RESET}"
        log_detail "  Resolution: $resolution"
        log_detail "  Position: $position"
        echo ""
    done

    if [ "$display_count" -ne 2 ]; then
        log_warn "Expected 2 displays, found $display_count"
    fi

    # Detect touchscreen devices
    log_section "3. TOUCHSCREEN DEVICE DETECTION"

    log_info "Searching for pattern: ${BOLD}$TOUCHSCREEN_PATTERN${RESET}"
    echo ""

    device_ids=$(get_all_xinput_ids)
    device_count=$(echo "$device_ids" | wc -w)

    if [ -z "$device_ids" ] || [ "$device_count" -eq 0 ]; then
        log_error "No touchscreen devices found matching pattern"
        echo ""
        log_subsection "All Available Input Devices"
        xinput list
        exit 1
    fi

    log_info "Found $device_count matching device(s)"
    echo ""

    # Detailed device analysis
    log_section "4. DEVICE ANALYSIS"

    declare -A device_info
    touch_device_ids=""

    for id in $device_ids; do
        log_subsection "Device ID: $id"

        name=$(get_device_name "$id")
        node=$(get_device_node "$id")
        type=$(get_device_type "$id")
        usb_port=$(get_usb_port "$node")
        product_id=$(get_device_product_id "$node")

        log_detail "Name: ${BOLD}$name${RESET}"
        log_detail "Device Node: ${BOLD}${node:-N/A}${RESET}"
        log_detail "Device Type: ${BOLD}$type${RESET}"
        log_detail "USB Port: ${BOLD}$usb_port${RESET}"
        log_detail "Product ID: ${BOLD}$product_id${RESET}"

        # Check capabilities
        echo ""
        log_detail "Capabilities:"

        if has_absolute_axes "$id"; then
            log_info "  Has absolute axes (touch capable)"
        else
            log_warn "  No absolute axes (not a touch device)"
        fi

        if has_coordinate_transformation "$id"; then
            log_info "  Has coordinate transformation (mappable)"
        else
            log_warn "  No coordinate transformation (cannot map to display)"
        fi

        if is_device_enabled "$id"; then
            log_info "  Device is enabled"
        else
            log_warn "  Device is disabled"
        fi

        # Store device info
        device_info["$id,name"]="$name"
        device_info["$id,node"]="$node"
        device_info["$id,type"]="$type"
        device_info["$id,usb"]="$usb_port"
        device_info["$id,product"]="$product_id"

        if [ "$type" = "TOUCH" ]; then
            touch_device_ids="$touch_device_ids $id"
        fi

        echo ""
    done

    # Analyze touch devices
    log_section "5. TOUCH DEVICE IDENTIFICATION"

    touch_count=$(echo "$touch_device_ids" | wc -w)

    if [ "$touch_count" -eq 0 ]; then
        log_error "No actual touch devices identified!"
        log_warn "All $device_count devices appear to be mouse emulation or other types"
        echo ""
        log_warn "Recommendation: Check device properties manually"
    elif [ "$touch_count" -eq 2 ]; then
        log_info "Successfully identified 2 touch devices: $touch_device_ids"
    else
        log_warn "Found $touch_count touch devices (expected 2): $touch_device_ids"
    fi

    echo ""

    # USB port mapping
    log_section "6. USB PORT MAPPING ANALYSIS"

    if [ "$touch_count" -ge 2 ]; then
        declare -A port_to_device

        for id in $touch_device_ids; do
            usb="${device_info[$id,usb]}"
            if [ "$usb" != "N/A" ]; then
                port_to_device["$usb"]="$id"
                log_detail "USB Port ${BOLD}$usb${RESET} → Device ${BOLD}$id${RESET}"
            else
                log_warn "Device $id has no USB port information"
            fi
        done

        echo ""

        # Sort ports and create recommended mapping
        sorted_ports=($(printf '%s\n' "${!port_to_device[@]}" | sort -V))

        if [ "${#sorted_ports[@]}" -ge 2 ]; then
            log_info "Recommended mapping (based on USB port order):"
            echo ""
            log_detail "USB Port ${BOLD}${sorted_ports[0]}${RESET} (Device ${BOLD}${port_to_device[${sorted_ports[0]}]}${RESET}) → ${GREEN}HDMI-1 (Primary)${RESET}"
            log_detail "USB Port ${BOLD}${sorted_ports[1]}${RESET} (Device ${BOLD}${port_to_device[${sorted_ports[1]}]}${RESET}) → ${GREEN}HDMI-2 (Secondary)${RESET}"
        fi
    fi

    # Current mapping status
    log_section "7. CURRENT MAPPING STATUS"

    for id in $device_ids; do
        log_detail "Device $id (${device_info[$id,type]}):"

        # Check coordinate transformation matrix
        matrix=$(xinput list-props "$id" 2>/dev/null | grep "Coordinate Transformation Matrix:" | grep -oP ':\s+\K.*' || echo "")

        if [ -n "$matrix" ]; then
            # Parse matrix to determine if mapped
            first_val=$(echo "$matrix" | awk '{print $1}')
            if [ "$first_val" = "1.000000," ] || [ "$first_val" = "1.000000" ]; then
                log_info "  Not specifically mapped (using default)"
            else
                log_info "  Has custom transformation: $matrix"
            fi
        else
            log_warn "  No coordinate transformation matrix"
        fi
    done

    # Device properties dump (verbose mode)
    if [ "$VERBOSE" = true ]; then
        log_section "8. DETAILED DEVICE PROPERTIES (VERBOSE)"

        for id in $device_ids; do
            log_subsection "Full Properties for Device $id"
            xinput list-props "$id" 2>/dev/null || echo "Could not retrieve properties"
            echo ""
        done
    fi

    # USB device tree
    log_section "8. USB DEVICE TOPOLOGY"

    if command -v lsusb &> /dev/null; then
        log_info "USB device tree:"
        echo ""
        lsusb -t 2>/dev/null || log_warn "Could not retrieve USB tree"
    else
        log_warn "lsusb not available"
    fi

    echo ""

    # Recommendations
    log_section "9. RECOMMENDATIONS & SUMMARY"

    echo -e "${BOLD}Summary:${RESET}"
    echo -e "  • Total matching devices: ${BOLD}$device_count${RESET}"
    echo -e "  • Touch-capable devices: ${BOLD}$touch_count${RESET}"
    echo -e "  • Connected displays: ${BOLD}$display_count${RESET}"
    echo ""

    echo -e "${BOLD}Touch Device IDs:${RESET} $touch_device_ids"
    echo ""

    if [ "$touch_count" -eq 2 ] && [ "$display_count" -eq 2 ]; then
        log_info "Configuration appears correct for dual-kiosk setup"
        echo ""

        echo -e "${BOLD}Recommended Configuration:${RESET}"
        echo ""
        echo "Add to ${CYAN}/boot/firmware/kiosk_config.sh${RESET}:"
        echo ""
        echo -e "${YELLOW}# Use flexible pattern matching${RESET}"
        echo -e "TOUCHSCREEN_PATTERN=\"Weida Hi-Tech.*CoolTouchR System\""
        echo ""
        echo -e "${YELLOW}# Touch device IDs (detected):${RESET}"
        echo -e "# ${touch_device_ids}"
        echo ""

        if [ "${#sorted_ports[@]}" -ge 2 ]; then
            echo -e "${YELLOW}# Recommended mapping based on USB port order:${RESET}"
            echo -e "# USB ${sorted_ports[0]} (Device ${port_to_device[${sorted_ports[0]}]}) → HDMI-1"
            echo -e "# USB ${sorted_ports[1]} (Device ${port_to_device[${sorted_ports[1]}]}) → HDMI-2"
        fi
        echo ""

    elif [ "$touch_count" -lt 2 ]; then
        log_error "Insufficient touch devices detected"
        echo ""
        echo "Possible issues:"
        echo "  • Touchscreens not properly connected"
        echo "  • Driver not loaded"
        echo "  • Wrong device pattern"
        echo "  • USB power issue"
    elif [ "$display_count" -ne 2 ]; then
        log_warn "Display count mismatch"
        echo ""
        echo "Verify:"
        echo "  • Both HDMI cables connected"
        echo "  • Monitors powered on"
        echo "  • xrandr shows both displays"
    else
        log_warn "Configuration needs review"
    fi

    echo ""
    log_section "DIAGNOSTIC COMPLETE"
    echo ""
    echo -e "Full report saved to: ${BOLD}${GREEN}$OUTPUT_FILE${RESET}"
    echo ""
}

# Run main function
main "$@"
