# HDMI-1 Display Detection Fix

## Problem Description

HDMI-1 display not being detected on boot, but HDMI-2 works. Touch inputs from HDMI-1's touchscreen are detected but projected onto HDMI-2 (the only active display).

## Root Cause

**Timing Issue**: The original code ran `xrandr` commands immediately after a 2-second delay. This wasn't enough time for both HDMI displays to be detected by the system, especially HDMI-1.

**What was happening:**
```
Boot → Sleep 2s → xrandr commands run
    ↓
HDMI-1: Not yet detected ✗
HDMI-2: Detected ✓
    ↓
Only HDMI-2 configured
    ↓
Touch devices mapped to displays:
  - Touch 1 → HDMI-1 (but HDMI-1 doesn't exist)
  - Touch 2 → HDMI-2 ✓
    ↓
Both touch inputs appear on HDMI-2
```

## Solution Implemented

Added **robust display detection with retry logic** in `010_xephyr.sh`:

### New Function: `configure_displays()`

**Features:**
1. **Detection Loop**: Checks for both displays up to 10 times
2. **Progressive Retry**: Waits 2 seconds between attempts
3. **Visual Feedback**: Prints detection status with ✓/✗ markers
4. **Graceful Degradation**: Configures whatever displays are found
5. **Proper Timing**: Adds sleep after each xrandr command

### How It Works

```bash
configure_displays() {
    # Loop up to 10 attempts (20 seconds total)
    for attempt in 1..10; do
        # Check if HDMI-1 is connected
        if xrandr shows "HDMI-1 connected":
            hdmi1_found=true

        # Check if HDMI-2 is connected
        if xrandr shows "HDMI-2 connected":
            hdmi2_found=true

        # If both found, configure and exit
        if both displays found:
            Configure HDMI-1 at position 0x0 (primary)
            Configure HDMI-2 at position 1920x0 (secondary)
            return success

        # Otherwise, wait 2s and retry
        sleep 2
    done

    # If timeout, configure whatever was found
    Configure any detected displays
}
```

### Code Location

**File**: `rootfs/home/pi/010_xephyr.sh`
**Lines**: 35-104

## Additional Troubleshooting

If HDMI-1 still doesn't detect after this fix, try these solutions:

### Option 1: Force HDMI Hotplug Detection

Add to `/boot/firmware/config.txt`:

```bash
# Force HDMI hotplug detection
hdmi_force_hotplug:0=1  # For HDMI-1
hdmi_force_hotplug:1=1  # For HDMI-2

# Force HDMI output even if no display detected
hdmi_drive:0=2          # For HDMI-1
hdmi_drive:1=2          # For HDMI-2

# Set specific HDMI mode
hdmi_group:0=2          # For HDMI-1 (DMT)
hdmi_mode:0=82          # 1920x1080@60Hz

hdmi_group:1=2          # For HDMI-2 (DMT)
hdmi_mode:1=82          # 1920x1080@60Hz
```

**Note**: The `:0` suffix is for HDMI-1, `:1` is for HDMI-2 on Raspberry Pi 4/5.

### Option 2: Check Physical Connections

1. **Verify cables**:
   - HDMI-1 cable firmly connected to Pi
   - HDMI-1 cable firmly connected to left monitor
   - Try swapping cables between HDMI-1 and HDMI-2

2. **Check monitor power**:
   - Both monitors powered on
   - Both monitors on correct input source
   - Try powering monitors on before booting Pi

3. **Test individual displays**:
   ```bash
   # Boot with only HDMI-1 connected
   # Does it detect?

   # Boot with only HDMI-2 connected
   # Does it detect?
   ```

### Option 3: Increase Initial Delay

If displays need more time to initialize, increase the initial sleep in `010_xephyr.sh`:

```bash
# Change from:
sleep 2

# To:
sleep 5
```

### Option 4: Manual Display Activation

If auto-detection fails, manually force displays on:

```bash
# In 010_xephyr.sh, before configure_displays():

# Force turn on both HDMI outputs
DISPLAY=:0 xrandr --output HDMI-1 --auto 2>/dev/null || true
DISPLAY=:0 xrandr --output HDMI-2 --auto 2>/dev/null || true
sleep 2

# Then run detection
configure_displays
```

## Diagnostic Script

Run this script on the Pi to diagnose display issues:

```bash
DISPLAY=:0 bash diagnose_displays.sh > display_diagnostic.txt
cat display_diagnostic.txt
```

**Key things to check in output:**
1. Both HDMI-1 and HDMI-2 show as "connected" in xrandr
2. Both have proper resolutions (1920x1080)
3. HDMI-1 is at position 0x0
4. HDMI-2 is at position 1920x0 (or 1080x0 for portrait)
5. Touch devices have different coordinate transformation matrices

## Expected Behavior After Fix

### On Boot:
```
Detecting displays...
Attempt 1/10: Checking for displays...
  ✗ HDMI-1 not detected
  ✓ HDMI-2 detected
Waiting for displays... (1s)

Attempt 2/10: Checking for displays...
  ✓ HDMI-1 detected
  ✓ HDMI-2 detected
Both displays detected! Configuring...
Display configuration complete
```

### Display Configuration:
- HDMI-1: 1920x1080 at position 0x0 (primary)
- HDMI-2: 1920x1080 at position 1920x0 (secondary)
- Both rotated according to ORIENTATION setting

### Touch Mapping:
- Touch device 1 → HDMI-1 (left screen)
- Touch device 2 → HDMI-2 (right screen)
- Independent cursor control

## Testing After Deployment

1. **Verify both displays active**:
   ```bash
   DISPLAY=:0 xrandr | grep " connected"
   # Should show both HDMI-1 and HDMI-2
   ```

2. **Check display positions**:
   ```bash
   DISPLAY=:0 xrandr
   # HDMI-1 should show: 1920x1080+0+0
   # HDMI-2 should show: 1920x1080+1920+0
   ```

3. **Test touch on left screen** → cursor moves on left screen
4. **Test touch on right screen** → cursor moves on right screen
5. **Verify browsers on correct screens**:
   - Browser 1 visible on HDMI-1 (left)
   - Browser 2 visible on HDMI-2 (right)

## Rollback

If this causes issues:

```bash
# Restore original simple xrandr commands
# Edit /home/pi/010_xephyr.sh

# Replace configure_displays() call with:
sleep 2
xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --rotate "$ORIENTATION" --primary
xrandr --output HDMI-2 --mode 1920x1080 --pos 1920x0 --rotate "$ORIENTATION"
```

## Technical Details

### Why Detection Can Fail

1. **EDID Communication Delay**: Monitor's EDID (Extended Display Identification Data) not ready
2. **HPD (Hot Plug Detect) Timing**: HDMI hot-plug detection signal delayed
3. **Display Power-On Time**: Monitor takes time to fully power on and respond
4. **GPU Driver Initialization**: vc4 (VideoCore 4) driver not fully initialized
5. **I2C Bus Timing**: I2C communication for EDID can be slow on some monitors

### What xrandr Does

```bash
xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --rotate right --primary

# Breaks down to:
--output HDMI-1       # Target this display
--mode 1920x1080      # Set resolution
--pos 0x0             # Position at coordinates X=0, Y=0
--rotate right        # Rotate 90° clockwise (portrait)
--primary             # Make this the primary display
```

### Display Detection Process

1. **Query displays**: `xrandr` queries kernel DRM subsystem
2. **Check connection**: Reads HPD pin state
3. **Read EDID**: Communicates via I2C to get monitor capabilities
4. **Parse modes**: Extracts supported resolutions/refresh rates
5. **Configure output**: Sends mode-setting commands to GPU

## Files Modified

- **`rootfs/home/pi/010_xephyr.sh`** (lines 27-104)
  - Replaced simple xrandr commands with robust detection function
  - Added retry logic with up to 10 attempts
  - Added visual feedback and logging
  - Added graceful degradation for partial detection

## Files Created

- **`diagnose_displays.sh`** - Comprehensive display diagnostic script
- **`DISPLAY_DETECTION_FIX.md`** - This document

## Related Issues

This fix also helps with:
- Display not detected after reboot
- Random "display not found" errors
- Slow monitor power-on causing detection failure
- EDID communication timeouts
- Hot-plug detection delays

## Prevention

To prevent this issue in the future:
1. **Keep firmware updated**: `sudo rpi-update`
2. **Use quality HDMI cables**: Poor cables can cause HPD issues
3. **Power monitors before Pi**: Ensures displays ready when Pi boots
4. **Check boot config**: Verify no conflicting HDMI settings

---

**Implementation Date**: 2025-10-29
**Status**: Ready for deployment
**Estimated Fix Time**: < 30 seconds (automatic retry)
**Max Wait Time**: 20 seconds (10 attempts × 2s)
