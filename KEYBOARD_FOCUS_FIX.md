# Keyboard Focus Fix - Additional Implementation

## Diagnostic Analysis

After reviewing the keyboard diagnostic output, I identified the missing piece:

### What the Diagnostic Showed

```
Physical Keyboard: SEM USB Keyboard (id=10)
Attached to: Virtual core keyboard (id=3) ✓ CORRECT

MPX Setup:
- Kiosk1 pointer (id=19) + Kiosk1 keyboard (id=20)
- Kiosk2 pointer (id=23) + Kiosk2 keyboard (id=24)

Problem: "No active window detected"
```

### The Issue

The keyboard was already on Virtual core (as my fix intended), but **windows didn't have focus** and weren't configured to accept input from Virtual core keyboard.

## Root Cause

In Multi-Pointer X (MPX), each window has a "**client pointer**" that determines which master pointer/keyboard pair it listens to.

**The problem flow:**
1. Chromium windows launch
2. They may inherit client pointer from parent OR get auto-assigned
3. If assigned to Kiosk1/Kiosk2 pointer, they only listen to Kiosk1/Kiosk2 keyboard
4. Kiosk1/Kiosk2 keyboards have no physical devices attached
5. Physical keyboard is on Virtual core keyboard
6. Result: Windows don't receive keyboard input

## Solution Implemented

Modified `rootfs/home/pi/010_xephyr.sh` to add **client pointer management** after browser launch:

### Code Added (lines 115-134)

```bash
# Configure keyboard focus for MPX compatibility
# Ensures Chromium windows accept keyboard input from Virtual core keyboard

# Find all Chromium windows
CHROMIUM_WINDOWS=$(DISPLAY=:0 xdotool search --sync --onlyvisible --class "Chromium")

for window_id in $CHROMIUM_WINDOWS; do
    # Set client pointer to Virtual core pointer (id=2)
    xinput set-client-pointer "$window_id" 2

    # Give window focus
    xdotool windowfocus --sync "$window_id"
done
```

### What This Does

1. **Waits for browsers to launch** (3 second delay)
2. **Finds all Chromium windows** using xdotool
3. **Sets client pointer** for each window to Virtual core pointer (id=2)
   - Virtual core pointer is paired with Virtual core keyboard
   - Virtual core keyboard has the physical USB keyboard attached
4. **Gives focus** to each window
5. **Result**: Windows now receive keyboard input from physical keyboard

## Why Both Fixes Are Needed

### Fix 1: Keyboard Routing (`touchscreen-setup.sh`)
- Ensures physical keyboards are attached to Virtual core keyboard
- Runs during MPX setup (early in boot)
- **Fixes**: Where the keyboard is attached

### Fix 2: Client Pointer Management (`010_xephyr.sh`) - **THIS FIX**
- Ensures Chromium windows listen to Virtual core pointer/keyboard
- Runs after browsers launch (late in boot)
- **Fixes**: Which keyboard the windows listen to

**Both are required** for keyboard input to work in MPX environments.

## Technical Details

### MPX Client Pointer Mechanism

```
Window Creation:
    ↓
Window needs client pointer assignment
    ↓
Options:
1. Inherit from parent window
2. Auto-assign based on which pointer created it
3. Manually set with xinput set-client-pointer
    ↓
Window only accepts input from its client pointer's keyboard
```

**Without this fix:**
```
Chromium Window
    ↓
Client Pointer: Kiosk1 pointer (id=19) [auto-assigned]
    ↓
Listens to: Kiosk1 keyboard (id=20)
    ↓
Kiosk1 keyboard has: Only XTEST device (no physical keyboard)
    ↓
Result: No keyboard input ✗
```

**With this fix:**
```
Chromium Window
    ↓
Client Pointer: Virtual core pointer (id=2) [manually set]
    ↓
Listens to: Virtual core keyboard (id=3)
    ↓
Virtual core keyboard has: SEM USB Keyboard (id=10)
    ↓
Result: Keyboard input works ✓
```

## Testing

### Verify Client Pointer Assignment

```bash
# Get window ID of a Chromium browser
WINDOW_ID=$(xdotool search --class "Chromium" | head -1)

# Check which client pointer it has
xinput query-state "$WINDOW_ID"

# Should show: Virtual core pointer (id=2)
```

### Verify Keyboard Input

```bash
# Click in browser window
# Type on keyboard
# Should see text appear in focused input fields
```

## Deployment Notes

This fix is integrated into the same deployment as the previous fixes:
- Copy updated `010_xephyr.sh` to Raspberry Pi
- Reboot or restart kiosk session
- Keyboard should work in both browsers

## Troubleshooting

### If keyboard still doesn't work after this fix:

1. **Check if windows found**:
   ```bash
   # Look for this message in console:
   "Configured keyboard input for 2 browser window(s)"

   # If you see: "Warning: No Chromium windows found yet"
   # Increase sleep time before xdotool search
   ```

2. **Manually verify client pointer**:
   ```bash
   DISPLAY=:0 xdotool search --class "Chromium"
   # Get window IDs

   DISPLAY=:0 xinput list-props <window-id>
   # Check "Client Pointer" property
   ```

3. **Manually set client pointer**:
   ```bash
   # For each Chromium window:
   DISPLAY=:0 xinput set-client-pointer <window-id> 2
   ```

## Summary

**Problem**: Keyboard attached to Virtual core, but windows listening to Kiosk keyboards

**Solution**: Explicitly set client pointer for Chromium windows to Virtual core pointer

**Result**: Physical keyboard input now reaches both browsers

---

**Implementation Date**: 2025-10-29
**File Modified**: `rootfs/home/pi/010_xephyr.sh` (lines 115-134)
**Status**: Ready for deployment with other keyboard/password fixes
