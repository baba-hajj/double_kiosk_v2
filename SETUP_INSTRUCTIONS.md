# Dual-Kiosk Setup Instructions

## Overview

This system provides independent dual-touchscreen kiosk functionality using Multi-Pointer X (MPX) for complete user independence.

## What's New

✅ **Multi-Pointer X (MPX)** - Two independent cursors, one per screen
✅ **Automatic Device Detection** - USB-based stable device identification
✅ **Performance Optimization** - Mouse emulation devices disabled
✅ **Comprehensive Logging** - Detailed logs for troubleshooting
✅ **Graceful Fallback** - Legacy mode if MPX setup fails

---

## Installation Steps

### 1. Copy Files to Raspberry Pi

```bash
# Copy all files to their destinations
sudo cp rootfs/home/pi/lib/*.sh /home/pi/lib/
sudo cp rootfs/home/pi/010_*.sh /home/pi/
sudo cp bootfs/kiosk_config.sh /boot/firmware/kiosk_config.sh
sudo cp rootfs/etc/xdg/openbox/rc.xml /etc/xdg/openbox/rc.xml
sudo cp rootfs/home/pi/.profile /home/pi/.profile

# Set correct permissions
chmod +x /home/pi/010_*.sh
chmod +x /home/pi/lib/*.sh

# Create log directory
sudo mkdir -p /var/log/kiosk
sudo chown pi:pi /var/log/kiosk
```

### 2. Configure System

Edit `/boot/firmware/kiosk_config.sh` to customize:

```bash
# URL for kiosks
URL="https://your-kiosk-url.com"

# Display orientation
ORIENTATION="right"  # or "normal" for landscape

# Touchscreen pattern (default works for Weida Hi-Tech)
TOUCHSCREEN_PATTERN="Weida Hi-Tech.*CoolTouchR System"

# Logging level (2 = info, recommended)
TOUCHSCREEN_LOG_LEVEL=2
```

### 3. Reboot

```bash
sudo reboot
```

---

## Verification

### Check Touchscreen Setup

After reboot, verify the system is working:

```bash
# Check log file for any errors
cat /var/log/kiosk/touchscreen.log

# Verify MPX pointers exist
DISPLAY=:0 xinput list | grep -i kiosk

# Should show:
# - Kiosk1 pointer
# - Kiosk2 pointer
```

### Expected Behavior

✅ Two independent cursors visible (one per screen)
✅ Person A touches left screen → Only left cursor moves
✅ Person B touches right screen → Only right cursor moves
✅ Both users can browse independently
✅ No focus stealing between screens

---

## Troubleshooting

### Issue: Only one cursor visible

**Cause:** MPX setup may have failed

**Solution:**
```bash
# Check the log
cat /var/log/kiosk/touchscreen.log

# Look for errors in MPX setup
# Common issues:
# - Device detection failed
# - USB controller grouping failed
# - MPX pointer creation failed
```

### Issue: Touchscreens not responding

**Cause:** Wrong device pattern or disconnected touchscreens

**Solution:**
```bash
# List all input devices
DISPLAY=:0 xinput list

# Find your touchscreen devices
# Update TOUCHSCREEN_PATTERN in /boot/firmware/kiosk_config.sh
```

### Issue: Lag or poor performance

**Cause:** Mouse emulation devices still enabled

**Solution:**
```bash
# Verify mouse emulation is disabled
DISPLAY=:0 xinput list

# Devices with "Mouse" suffix should show "(floating)"
# or should not be listed under a master pointer

# If still attached, they should be disabled
# Check log for confirmation
```

### Issue: Devices change IDs on reboot

**Cause:** This is normal behavior

**Solution:** The new system automatically handles this by using USB controller detection instead of device IDs. No action needed.

---

## Configuration Options

### Touchscreen Pattern

For different touchscreen brands, update the pattern:

```bash
# Weida Hi-Tech (default)
TOUCHSCREEN_PATTERN="Weida Hi-Tech.*CoolTouchR System"

# ILITEK touchscreens
TOUCHSCREEN_PATTERN="ILITEK.*ILITEK-TOUCH"

# Generic pattern (match all touch devices)
TOUCHSCREEN_PATTERN=".*Touch.*"
```

### Logging Levels

```bash
TOUCHSCREEN_LOG_LEVEL=0  # No logging (not recommended)
TOUCHSCREEN_LOG_LEVEL=1  # Errors only
TOUCHSCREEN_LOG_LEVEL=2  # Info + Errors (recommended)
TOUCHSCREEN_LOG_LEVEL=3  # Debug + Info + Errors (verbose)
```

### Manual Device Override

If automatic detection fails, you can manually specify device IDs:

```bash
# Find device IDs
DISPLAY=:0 xinput list

# In kiosk_config.sh:
TOUCHSCREEN_1_DEVICE_ID="6"  # Device for left screen
TOUCHSCREEN_2_DEVICE_ID="9"  # Device for right screen
```

**Note:** Device IDs may change on reboot, so this is not recommended unless necessary.

---

## Architecture

### System Flow

```
Boot → .profile → 010_run_xephyr.sh → 010_xephyr.sh
                                        ├─ Load config
                                        ├─ Configure displays
                                        ├─ Setup touchscreens (MPX) ← NEW
                                        ├─ Start Xephyr sessions
                                        └─ Launch browsers + keyboards
```

### Touchscreen Setup Flow

```
setup_touchscreens_mpx()
├─ 1. Detect devices (pattern matching)
├─ 2. Filter touch vs mouse emulation
├─ 3. Group by USB controller
├─ 4. Create MPX master pointers
├─ 5. Attach devices to pointers
├─ 6. Map to displays
├─ 7. Disable mouse emulation
└─ 8. Validate setup
```

### File Structure

```
/boot/firmware/
└── kiosk_config.sh              # User configuration

/home/pi/
├── .profile                     # Auto-launch trigger
├── 010_run_xephyr.sh           # X server wrapper
├── 010_xephyr.sh               # Main kiosk script
└── lib/
    ├── logging.sh              # Logging functions
    └── touchscreen-setup.sh    # MPX setup logic

/var/log/kiosk/
└── touchscreen.log             # Runtime logs

/home/pi/bin/                    # Diagnostic tools
├── diagnose-touchscreens.sh
├── test-touchscreen-mapping.sh
└── gather-touchscreen-info.sh
```

---

## Diagnostic Tools

### Full Diagnostic

```bash
cd /home/pi/bin
./diagnose-touchscreens.sh
```

Provides comprehensive analysis of touchscreen setup.

### Quick Info Gathering

```bash
cd /home/pi/bin
./gather-touchscreen-info.sh
```

Gathers system information for troubleshooting.

### Manual Mapping Test

```bash
cd /home/pi/bin
./test-touchscreen-mapping.sh <device_id_1> <device_id_2>
```

Test specific device-to-display mapping.

---

## Performance Notes

**Expected Resource Usage:**
- CPU: ~30-40% with two Chromium instances
- RAM: ~1-1.5GB total
- No noticeable input lag with mouse emulation disabled

**Optimization Tips:**
- Disable mouse emulation devices (already done by default)
- Use `--disable-gpu` flag in Chromium if rendering issues occur
- Increase `gpu_mem` in `/boot/firmware/config.txt` if needed

---

## Support

### View Logs

```bash
# Real-time log viewing
tail -f /var/log/kiosk/touchscreen.log

# Full log
cat /var/log/kiosk/touchscreen.log
```

### Reset to Defaults

```bash
# Reset configuration
sudo cp /home/pi/double_kiosk/bootfs/kiosk_config.sh /boot/firmware/kiosk_config.sh

# Clear logs
sudo rm /var/log/kiosk/touchscreen.log

# Reboot
sudo reboot
```

### Report Issues

When reporting issues, please include:
1. Contents of `/var/log/kiosk/touchscreen.log`
2. Output of `DISPLAY=:0 xinput list`
3. Touchscreen model and connection type
4. Description of the issue

---

## Changelog

### Version 2.0 (2025-10-28)
- ✅ Implemented Multi-Pointer X (MPX) for independent cursors
- ✅ Added USB controller-based device detection (stable across reboots)
- ✅ Performance optimization (mouse emulation device disabling)
- ✅ Comprehensive logging system
- ✅ Graceful fallback to legacy mode
- ✅ Enhanced configuration options

### Version 1.0 (Initial)
- Basic dual-kiosk functionality
- Simple device mapping (shared cursor)
