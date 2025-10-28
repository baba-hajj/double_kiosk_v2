# Touchscreen Diagnostic Guide

## Overview

This diagnostic tool analyzes your dual-touchscreen kiosk setup and provides detailed information about device detection, USB topology, and mapping recommendations.

## Quick Start

### On Your Raspberry Pi (with displays connected):

```bash
# Navigate to the repository
cd /path/to/double_kiosk

# Run the diagnostic script
./bin/diagnose-touchscreens.sh
```

The script will:
- ✓ Detect all touchscreen devices
- ✓ Identify which are actual touch devices vs mouse emulation
- ✓ Map devices to USB ports
- ✓ Analyze display configuration
- ✓ Provide configuration recommendations
- ✓ Save a detailed report

## Usage Options

```bash
# Basic diagnostic (recommended for first run)
./bin/diagnose-touchscreens.sh

# Verbose mode (includes full device properties)
./bin/diagnose-touchscreens.sh --verbose

# JSON output (for automated processing)
./bin/diagnose-touchscreens.sh --json

# Help
./bin/diagnose-touchscreens.sh --help
```

## What the Script Checks

### 1. System Prerequisites
- X server accessibility
- Required commands (xinput, xrandr, udevadm)
- Display connection

### 2. Display Configuration
- Number of connected displays
- Resolution for each display
- Position/layout of displays

### 3. Device Detection
- All devices matching "Weida Hi-Tech CoolTouchR System"
- Device names and IDs
- Device node paths (/dev/input/eventX)

### 4. Device Analysis
For each device, the script checks:
- **Device Type**: Touch device vs mouse emulation
- **Absolute Axes**: Required for touch input
- **Coordinate Transformation**: Required for display mapping
- **USB Port**: Physical connection location
- **Enable Status**: Whether device is active

### 5. USB Topology
- USB port assignment for each device
- Stable port identifiers
- Device enumeration order

### 6. Mapping Recommendations
- Which devices should be mapped
- Suggested display assignments
- Configuration snippets for kiosk_config.sh

## Understanding the Output

### Device Types

The script classifies devices into types:

**TOUCH**
- Has absolute axes (Abs MT Position X/Y or Abs X/Y)
- Has coordinate transformation matrix
- **This is what we want to map**

**MOUSE_EMULATION**
- Device name contains "Mouse"
- May have relative axes instead of absolute
- Usually not needed for touch mapping

**UNKNOWN**
- Device properties unclear
- May require manual investigation

### Expected Results for Your Hardware

Based on the xinput list you provided, we expect:

```
Total devices found: 4
├── Device 6: MOUSE_EMULATION (with "Mouse" suffix)
├── Device 7: TOUCH (actual touch device)
├── Device 8: TOUCH (actual touch device)
└── Device 9: MOUSE_EMULATION (with "Mouse" suffix)
```

**We should map devices 7 and 8** (the TOUCH devices)

### USB Port Mapping

The script will show which USB port each device is connected to:

```
USB Port 1.2 → Device 7 → Should map to HDMI-1
USB Port 1.3 → Device 8 → Should map to HDMI-2
```

(Actual port numbers may vary on your system)

## What to Do With the Results

### Step 1: Review the Report

Look for these key sections:
- **Section 5**: Touch Device Identification
  - Should show 2 touch devices
- **Section 6**: USB Port Mapping Analysis
  - Shows recommended display assignments
- **Section 9**: Recommendations & Summary
  - Configuration snippets to use

### Step 2: Verify Physical Arrangement

Once you know which device IDs are touch devices:

1. **Test left monitor**: Touch the left screen
2. **Check which device ID responds**: Use `xinput test <device-id>`
3. **Test right monitor**: Touch the right screen
4. **Verify separate device IDs respond**

### Step 3: Share Results

**Please share with us:**

1. The generated report file (location shown at end of script)
2. Answer these questions:
   - How many "TOUCH" type devices were identified?
   - What are their device IDs?
   - What USB ports are they connected to?
   - Does the recommended mapping make sense?

### Step 4: Test Mapping Manually (Optional)

You can test the recommended mapping before implementing:

```bash
# Map device 7 to HDMI-1
xinput map-to-output 7 HDMI-1

# Map device 8 to HDMI-2
xinput map-to-output 8 HDMI-2

# Test touches on each screen
# Touch left screen - should work on left display
# Touch right screen - should work on right display
```

## Troubleshooting

### Script Fails with "Cannot connect to display"

```bash
# Ensure X server is running
echo $DISPLAY  # Should show :0 or similar

# If empty, set it
export DISPLAY=:0

# Try again
./bin/diagnose-touchscreens.sh
```

### No Devices Found

**Possible causes:**
- Touchscreens not connected
- USB cables loose
- Pattern mismatch in script

**Solutions:**
1. Check physical connections
2. Run `xinput list` to see all devices
3. Look for any device with "touch" in the name
4. Verify monitors are powered on

### Wrong Device Count

**If script finds 4 devices but only 2 are TOUCH:**
- ✓ Normal - some devices are mouse emulation
- Script will filter correctly

**If script finds 0 TOUCH devices:**
- ✗ Problem - may need to adjust device type detection
- Share the verbose output with us

### USB Port Shows "N/A"

**Causes:**
- udevadm not available
- Permissions issue
- Virtual device (no physical USB)

**Impact:**
- Can still map by device ID
- Just less stable across reboots

## Output Files

The script saves a complete report to:
```
/tmp/touchscreen-diagnostic-YYYYMMDD-HHMMSS.txt
```

This file contains all diagnostic information and can be:
- Shared for remote troubleshooting
- Kept as a reference
- Compared across reboots to detect changes

## Next Steps

After running diagnostics:

1. **Share Results**: Post the report or key findings
2. **Confirm Findings**: We'll verify the device identification
3. **Implement Solution**: Update detection code based on real hardware
4. **Test Implementation**: Verify touchscreens work correctly
5. **Deploy**: Roll out to production

## Advanced Usage

### Run on Boot for Monitoring

Add to cron or systemd to track device detection over time:

```bash
# Add to crontab
@reboot /path/to/diagnose-touchscreens.sh > /var/log/kiosk/touchscreen-boot-$(date +\%Y\%m\%d).log 2>&1
```

### Compare Multiple Runs

```bash
# Run multiple times and compare
./bin/diagnose-touchscreens.sh  # Generates report1
# Reboot system
./bin/diagnose-touchscreens.sh  # Generates report2
# Compare device IDs and USB ports
diff /tmp/touchscreen-diagnostic-*.txt
```

### Integration with Main Script

Once we confirm the correct device detection logic, we'll integrate these functions into the main `010_xephyr.sh` script.

## Questions?

If you encounter any issues or unexpected results:

1. Run with `--verbose` flag
2. Save the full output
3. Share with development team
4. Include any error messages

---

**Ready to run? Execute on your Raspberry Pi with both touchscreens connected!**
