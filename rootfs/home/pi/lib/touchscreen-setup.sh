#!/usr/bin/env bash
################################################################################
# Touchscreen Setup Library for Dual-Kiosk System
# Implements Multi-Pointer X (MPX) for independent touchscreen operation
################################################################################

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh" || {
    echo "ERROR: Could not load logging library" >&2
    exit 1
}

# Default configuration (can be overridden by kiosk_config.sh)
: "${TOUCHSCREEN_PATTERN:=Weida Hi-Tech.*CoolTouchR System}"
: "${ENABLE_MOUSE_EMULATION:=false}"

################################################################################
# Device Detection Functions
################################################################################

# Detect all touchscreen devices matching the pattern
# Returns: Space-separated list of device IDs
detect_all_touchscreen_devices() {
    log_debug "Searching for devices matching pattern: $TOUCHSCREEN_PATTERN"

    local all_ids=$(DISPLAY=:0 xinput list 2>/dev/null |
                    grep -E "$TOUCHSCREEN_PATTERN" |
                    grep -oP 'id=\K\d+' || echo "")

    if [ -z "$all_ids" ]; then
        log_error "No devices found matching pattern: $TOUCHSCREEN_PATTERN"
        return 1
    fi

    log_info "Found $(echo $all_ids | wc -w) devices matching pattern: $all_ids"
    echo "$all_ids"
    return 0
}

# Filter touch devices from mouse emulation devices
# Input: Space-separated list of device IDs
# Output: Sets TOUCH_DEVICES and MOUSE_DEVICES arrays
filter_touch_devices() {
    local all_devices="$1"

    TOUCH_DEVICES=()
    MOUSE_DEVICES=()

    for id in $all_devices; do
        local name=$(DISPLAY=:0 xinput list --name-only "$id" 2>/dev/null || echo "")

        if echo "$name" | grep -q "Mouse"; then
            MOUSE_DEVICES+=("$id")
            log_debug "Device $id: Mouse emulation - $name"
        else
            TOUCH_DEVICES+=("$id")
            log_debug "Device $id: Touch device - $name"
        fi
    done

    log_info "Touch devices: ${TOUCH_DEVICES[*]}"
    log_info "Mouse emulation devices: ${MOUSE_DEVICES[*]}"

    if [ ${#TOUCH_DEVICES[@]} -lt 2 ]; then
        log_error "Found only ${#TOUCH_DEVICES[@]} touch devices, need 2"
        return 1
    fi

    return 0
}

# Get USB controller for a device
# Input: Device ID
# Output: USB controller path (e.g., "xhci-hcd.0")
get_usb_controller() {
    local device_id=$1

    # Get device node
    local device_node=$(DISPLAY=:0 xinput list-props "$device_id" 2>/dev/null |
                        grep "Device Node" |
                        grep -oP '"/dev/input/\K[^"]+' || echo "")

    if [ -z "$device_node" ]; then
        log_debug "No device node found for device $device_id"
        echo ""
        return 1
    fi

    # Get USB controller from udev
    local usb_controller=$(udevadm info --query=property --name="/dev/input/$device_node" 2>/dev/null |
                          grep "DEVPATH=" |
                          grep -oP 'xhci-hcd\.\d+' |
                          head -1 || echo "")

    if [ -z "$usb_controller" ]; then
        log_debug "No USB controller found for device $device_id"
        echo ""
        return 1
    fi

    log_debug "Device $device_id on USB controller: $usb_controller"
    echo "$usb_controller"
    return 0
}

# Group devices by USB controller and return ordered device IDs
# Output: Sets ORDERED_TOUCH_DEVICES array [device_for_hdmi1, device_for_hdmi2]
group_by_usb_controller() {
    declare -A controller_to_device

    log_info "Grouping touch devices by USB controller..."

    for device_id in "${TOUCH_DEVICES[@]}"; do
        local controller=$(get_usb_controller "$device_id")

        if [ -n "$controller" ]; then
            controller_to_device["$controller"]="$device_id"
            log_debug "USB $controller → Device $device_id"
        else
            log_warn "Could not determine USB controller for device $device_id"
        fi
    done

    # Sort controllers and create ordered device list
    local sorted_controllers=($(printf '%s\n' "${!controller_to_device[@]}" | sort))

    if [ ${#sorted_controllers[@]} -lt 2 ]; then
        log_error "Only found ${#sorted_controllers[@]} USB controllers, need 2"
        return 1
    fi

    ORDERED_TOUCH_DEVICES=(
        "${controller_to_device[${sorted_controllers[0]}]}"
        "${controller_to_device[${sorted_controllers[1]}]}"
    )

    log_info "Ordered device mapping (by USB controller):"
    log_info "  HDMI-1 (Primary) ← Device ${ORDERED_TOUCH_DEVICES[0]} (USB ${sorted_controllers[0]})"
    log_info "  HDMI-2 (Secondary) ← Device ${ORDERED_TOUCH_DEVICES[1]} (USB ${sorted_controllers[1]})"

    return 0
}

################################################################################
# Multi-Pointer X (MPX) Setup Functions
################################################################################

# Create master pointers for MPX
create_mpx_pointers() {
    log_info "Creating Multi-Pointer X master pointers..."

    # Check if already exist
    if DISPLAY=:0 xinput list | grep -q "Kiosk1 pointer"; then
        log_debug "Kiosk1 pointer already exists"
    else
        if DISPLAY=:0 xinput create-master "Kiosk1" 2>/dev/null; then
            log_info "Created Kiosk1 master pointer"
        else
            log_error "Failed to create Kiosk1 master pointer"
            return 1
        fi
    fi

    if DISPLAY=:0 xinput list | grep -q "Kiosk2 pointer"; then
        log_debug "Kiosk2 pointer already exists"
    else
        if DISPLAY=:0 xinput create-master "Kiosk2" 2>/dev/null; then
            log_info "Created Kiosk2 master pointer"
        else
            log_error "Failed to create Kiosk2 master pointer"
            return 1
        fi
    fi

    return 0
}

# Attach touch devices to their dedicated master pointers
attach_devices_to_pointers() {
    log_info "Attaching touch devices to dedicated pointers..."

    # Attach device 1 to Kiosk1
    log_info "Attaching device ${ORDERED_TOUCH_DEVICES[0]} to Kiosk1 pointer"
    if ! DISPLAY=:0 xinput reattach "${ORDERED_TOUCH_DEVICES[0]}" "Kiosk1 pointer" 2>/dev/null; then
        log_error "Failed to attach device ${ORDERED_TOUCH_DEVICES[0]} to Kiosk1 pointer"
        return 1
    fi

    # Attach device 2 to Kiosk2
    log_info "Attaching device ${ORDERED_TOUCH_DEVICES[1]} to Kiosk2 pointer"
    if ! DISPLAY=:0 xinput reattach "${ORDERED_TOUCH_DEVICES[1]}" "Kiosk2 pointer" 2>/dev/null; then
        log_error "Failed to attach device ${ORDERED_TOUCH_DEVICES[1]} to Kiosk2 pointer"
        return 1
    fi

    log_info "Device attachment complete"
    return 0
}

# Disable mouse emulation devices to reduce overhead
disable_mouse_emulation() {
    if [ "$ENABLE_MOUSE_EMULATION" = "true" ]; then
        log_info "Mouse emulation enabled, keeping devices active"
        return 0
    fi

    if [ ${#MOUSE_DEVICES[@]} -eq 0 ]; then
        log_debug "No mouse emulation devices to disable"
        return 0
    fi

    log_info "Disabling mouse emulation devices for better performance..."

    for device_id in "${MOUSE_DEVICES[@]}"; do
        log_debug "Disabling device $device_id"
        if DISPLAY=:0 xinput disable "$device_id" 2>/dev/null; then
            log_info "Disabled mouse emulation device $device_id"
        else
            log_warn "Could not disable device $device_id (may not be critical)"
        fi
    done

    return 0
}

# Fix keyboard routing for MPX compatibility
# Ensures physical keyboards work in all windows regardless of pointer focus
fix_keyboard_routing() {
    log_info "Configuring keyboard routing for MPX compatibility..."

    # Find all physical keyboard devices (exclude virtual/pointer devices)
    local keyboard_ids=$(DISPLAY=:0 xinput list 2>/dev/null | \
                        grep -i "keyboard" | \
                        grep -v "Virtual core\|Kiosk.*keyboard\|pointer" | \
                        grep -oP 'id=\K\d+' || echo "")

    if [ -z "$keyboard_ids" ]; then
        log_warn "No physical keyboard devices found"
        return 0
    fi

    log_info "Found physical keyboard device(s): $keyboard_ids"

    # Reattach all physical keyboards to Virtual core keyboard
    # This ensures they work in all windows regardless of MPX pointer focus
    for kb_id in $keyboard_ids; do
        local kb_name=$(DISPLAY=:0 xinput list --name-only "$kb_id" 2>/dev/null || echo "unknown")
        log_info "Attaching keyboard $kb_id ($kb_name) to Virtual core keyboard"

        if DISPLAY=:0 xinput reattach "$kb_id" "Virtual core keyboard" 2>/dev/null; then
            log_info "Successfully attached keyboard $kb_id to Virtual core"
        else
            log_warn "Could not reattach keyboard $kb_id (may already be attached)"
        fi
    done

    log_info "Keyboard routing configuration complete"
    return 0
}

# Map touch devices to their respective displays
map_to_displays() {
    log_info "Mapping touch devices to displays..."

    # Map device 1 to HDMI-1
    log_info "Mapping device ${ORDERED_TOUCH_DEVICES[0]} to HDMI-1"
    if ! DISPLAY=:0 xinput map-to-output "${ORDERED_TOUCH_DEVICES[0]}" HDMI-1 2>/dev/null; then
        log_error "Failed to map device ${ORDERED_TOUCH_DEVICES[0]} to HDMI-1"
        return 1
    fi

    # Map device 2 to HDMI-2
    log_info "Mapping device ${ORDERED_TOUCH_DEVICES[1]} to HDMI-2"
    if ! DISPLAY=:0 xinput map-to-output "${ORDERED_TOUCH_DEVICES[1]}" HDMI-2 2>/dev/null; then
        log_error "Failed to map device ${ORDERED_TOUCH_DEVICES[1]} to HDMI-2"
        return 1
    fi

    log_info "Display mapping complete"
    return 0
}

################################################################################
# Validation Functions
################################################################################

# Validate that MPX setup is correct
validate_mpx_setup() {
    log_info "Validating MPX setup..."

    # Check master pointers exist
    if ! DISPLAY=:0 xinput list | grep -q "Kiosk1 pointer"; then
        log_error "Kiosk1 pointer not found"
        return 1
    fi

    if ! DISPLAY=:0 xinput list | grep -q "Kiosk2 pointer"; then
        log_error "Kiosk2 pointer not found"
        return 1
    fi

    # Check coordinate transformation matrices were applied
    for device_id in "${ORDERED_TOUCH_DEVICES[@]}"; do
        if DISPLAY=:0 xinput list-props "$device_id" 2>/dev/null | grep -q "Coordinate Transformation Matrix"; then
            log_debug "Device $device_id has coordinate transformation matrix"
        else
            log_warn "Device $device_id missing coordinate transformation matrix"
        fi
    done

    log_info "MPX validation passed"
    return 0
}

################################################################################
# Main Setup Function
################################################################################

# Main function to set up touchscreens with MPX
# This is the function called by 010_xephyr.sh
setup_touchscreens_mpx() {
    log_info "===== Starting Touchscreen MPX Setup ====="

    # Step 1: Detect all touchscreen devices
    local all_devices=$(detect_all_touchscreen_devices) || {
        log_error "Device detection failed"
        return 1
    }

    # Step 2: Filter touch devices from mouse emulation
    filter_touch_devices "$all_devices" || {
        log_error "Device filtering failed"
        return 1
    }

    # Step 3: Group devices by USB controller
    group_by_usb_controller || {
        log_error "USB controller grouping failed"
        return 1
    }

    # Step 4: Create MPX master pointers
    create_mpx_pointers || {
        log_error "MPX pointer creation failed"
        return 1
    }

    # Step 5: Attach devices to pointers
    attach_devices_to_pointers || {
        log_error "Device attachment failed"
        return 1
    }

    # Step 6: Fix keyboard routing for MPX compatibility
    fix_keyboard_routing

    # Step 7: Map to displays
    map_to_displays || {
        log_error "Display mapping failed"
        return 1
    }

    # Step 8: Disable mouse emulation (performance optimization)
    disable_mouse_emulation

    # Step 9: Validate setup
    validate_mpx_setup || {
        log_warn "MPX validation failed, but continuing anyway"
    }

    log_info "===== Touchscreen MPX Setup Complete ====="
    log_info "Two independent cursors should now be active:"
    log_info "  - Kiosk1 cursor on HDMI-1 (left screen)"
    log_info "  - Kiosk2 cursor on HDMI-2 (right screen)"

    return 0
}

################################################################################
# Fallback Function (Simple Mapping without MPX)
################################################################################

# Fallback to simple mapping if MPX fails
fallback_simple_mapping() {
    log_warn "Attempting fallback to simple touchscreen mapping (without MPX)"
    log_warn "Note: This will NOT provide independent cursors!"

    if [ ${#ORDERED_TOUCH_DEVICES[@]} -lt 2 ]; then
        log_error "No devices available for fallback mapping"
        return 1
    fi

    DISPLAY=:0 xinput map-to-output "${ORDERED_TOUCH_DEVICES[0]}" HDMI-1 2>/dev/null
    DISPLAY=:0 xinput map-to-output "${ORDERED_TOUCH_DEVICES[1]}" HDMI-2 2>/dev/null

    log_warn "Fallback mapping applied - users will share one cursor"
    return 0
}
