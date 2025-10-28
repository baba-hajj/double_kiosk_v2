# Config file for Dual Kiosk project

# ==============================================================================
# URL Configuration
# ==============================================================================
URL="https://kiosk.iheartjane.com/stores/6610/landing"

URL_01="$URL" # URL for the first browser
URL_02="$URL" # URL for the second browser

# ==============================================================================
# Display Configuration
# ==============================================================================

# Display orientation: normal|inverted|left|right
# normal = landscape, right = portrait (90° clockwise)
ORIENTATION="right"

# Note: On-screen keyboard (Onboard) has been removed
# Use a physical keyboard if text input is needed

# ==============================================================================
# Touchscreen Configuration
# ==============================================================================

# Device detection pattern (regex pattern to match touchscreen devices)
# Default works for Weida Hi-Tech CoolTouchR System touchscreens
TOUCHSCREEN_PATTERN="Weida Hi-Tech.*CoolTouchR System"

# Legacy patterns (for reference):
# TOUCHSCREEN_PATTERN="ILITEK.*ILITEK-TOUCH"  # For ILITEK touchscreens

# Enable/disable mouse emulation devices (default: false)
# Setting to false improves performance by disabling redundant input devices
ENABLE_MOUSE_EMULATION=false

# Logging configuration
# Log levels: 0=none, 1=errors only, 2=info, 3=debug
TOUCHSCREEN_LOG_LEVEL=2

# Log file location (will be created automatically)
TOUCHSCREEN_LOG="/var/log/kiosk/touchscreen.log"

# Manual device override (advanced users only)
# Leave empty for automatic detection based on USB controller
# If automatic detection fails, you can specify device IDs manually:
# TOUCHSCREEN_1_DEVICE_ID=""  # Device ID for HDMI-1 (left screen)
# TOUCHSCREEN_2_DEVICE_ID=""  # Device ID for HDMI-2 (right screen)

