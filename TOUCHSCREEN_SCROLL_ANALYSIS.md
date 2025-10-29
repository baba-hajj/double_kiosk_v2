# Touchscreen Scroll Analysis - Root Cause & Solution

## Executive Summary

**Issue**: Touch scrolling does not work in Chromium browsers on the dual-kiosk system. Users must use mouse-based scrollbars instead of finger-based touch scrolling.

**Root Cause**: Xephyr nested X servers do not forward XInput2 touch events from the host X server, only forwarding core pointer/keyboard events. Chromium requires XInput2 touch events for gesture-based scrolling.

**Impact**: Users can move cursor and click but cannot perform touch gestures (scroll, swipe, pinch-to-zoom).

---

## System Architecture Overview

### Current Implementation

```
┌─────────────────────────────────────────────────────────────┐
│ Hardware Layer                                               │
│ - Raspberry Pi 4/5                                          │
│ - 2x HDMI Touchscreen Monitors (Weida Hi-Tech)             │
│ - USB Touch Controllers (mapped to USB ports)               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Linux Kernel & Input Subsystem                              │
│ - /dev/input/eventX devices                                 │
│ - Multi-touch protocol support                              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Host X Server (DISPLAY=:0) ← TOUCHSCREEN MAPPING HERE      │
│                                                              │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Multi-Pointer X (MPX) Configuration                    │ │
│ │ - Kiosk1 pointer → Touch Device 1 → HDMI-1            │ │
│ │ - Kiosk2 pointer → Touch Device 2 → HDMI-2            │ │
│ │ - Coordinate Transformation Matrices applied           │ │
│ │ - XInput devices configured                            │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                              │
│   Touch Events (XInput2): ✓ Available                       │
│   - Touch Begin/Update/End                                  │
│   - Multi-touch gestures                                    │
│   - Pressure sensitivity                                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
            ┌──────────────┴──────────────┐
            ↓                              ↓
┌──────────────────────┐      ┌──────────────────────┐
│ Xephyr :1            │      │ Xephyr :2            │
│ (Nested X Server)    │      │ (Nested X Server)    │
│                      │      │                      │
│ Position: 0,0        │      │ Position: 1920,0     │
│ Size: 1080x1920      │      │ Size: 1080x1920      │
│                      │      │                      │
│ ⚠️  PROBLEM HERE:    │      │ ⚠️  PROBLEM HERE:    │
│ Only forwards:       │      │ Only forwards:       │
│ - Pointer motion     │      │ - Pointer motion     │
│ - Button events      │      │ - Button events      │
│ - Keyboard events    │      │ - Keyboard events    │
│                      │      │                      │
│ Does NOT forward:    │      │ Does NOT forward:    │
│ - XInput2 touch      │      │ - XInput2 touch      │
│ - Gesture events     │      │ - Gesture events     │
│ - Multi-touch data   │      │ - Multi-touch data   │
└──────────────────────┘      └──────────────────────┘
            ↓                              ↓
┌──────────────────────┐      ┌──────────────────────┐
│ OpenBox WM           │      │ OpenBox WM           │
└──────────────────────┘      └──────────────────────┘
            ↓                              ↓
┌──────────────────────┐      ┌──────────────────────┐
│ Chromium Browser     │      │ Chromium Browser     │
│ (DISPLAY=:1)         │      │ (DISPLAY=:2)         │
│                      │      │                      │
│ Receives:            │      │ Receives:            │
│ ✓ Pointer motion     │      │ ✓ Pointer motion     │
│ ✓ Click events       │      │ ✓ Click events       │
│ ✗ Touch scroll       │      │ ✗ Touch scroll       │
│ ✗ Gestures           │      │ ✗ Gestures           │
└──────────────────────┘      └──────────────────────┘
```

---

## Root Cause Analysis - First Principles

### Why Touchscreen Scrolling Requires Special Events

1. **Traditional Mouse Input**:
   - Pointer motion (X/Y coordinates)
   - Button press/release (left, right, middle)
   - Scroll wheel (discrete events)

2. **Modern Touch Input (XInput2)**:
   - Touch begin/update/end sequences
   - Multi-touch tracking (multiple fingers)
   - Gesture recognition (swipe, pinch, rotate)
   - Velocity and momentum data
   - Pressure sensitivity

3. **What Chromium Needs for Touch Scrolling**:
   - XInput2 extension version 2.2+
   - Touch event sequences to detect:
     - Single-finger drag = scroll
     - Two-finger drag = scroll
     - Flick gesture = momentum scroll
     - Pinch gesture = zoom

### The Breaking Point: Xephyr

**Xephyr is a nested X server** that runs as a client application inside a host X server. It presents itself as a window on the host display.

**How Xephyr receives input**:
```
User touches screen
    ↓
Linux kernel creates /dev/input/event
    ↓
Host X server (DISPLAY=:0) receives raw input
    ↓
XInput device driver processes touch event
    ↓
Coordinate transformation matrix applied
    ↓
MPX routes to correct master pointer
    ↓
Event delivered to focused window
    ↓
Xephyr window receives event AS AN X CLIENT
    ↓
Xephyr CONVERTS event for its nested clients
    ↓ ⚠️  CONVERSION LOSES INFORMATION
    ↓
Chromium receives CORE POINTER event, not touch event
```

**The Problem**:
- Xephyr acts as both:
  1. An X **client** (receiving events from host :0)
  2. An X **server** (sending events to nested apps)

- When converting events between these roles:
  - **Core pointer events** (motion, button) are forwarded ✓
  - **Keyboard events** are forwarded ✓
  - **XInput2 extension events** (touch, gestures) are NOT forwarded ✗

### Why This Design Exists

The current architecture uses Xephyr for:
1. **Display isolation**: Each browser gets its own X server
2. **Window positioning**: Precise control over screen placement
3. **Independent environments**: Separate profiles, no interaction

This was likely chosen because:
- Easier than manually positioning windows across dual displays
- Provides process isolation between kiosk instances
- Each Xephyr can have its own window manager

**However**, Xephyr was designed in an era when touch input was rare. XInput2 multi-touch support was added to X.Org 1.12 (2012), but Xephyr's forwarding logic was never updated to handle these events.

---

## Code Responsible for Touch Input

### Files Directly Responsible

#### 1. `/home/pi/lib/touchscreen-setup.sh` (Lines 228-247)
**Function**: `map_to_displays()`

**Purpose**: Maps touch devices to physical displays using coordinate transformation

**Code**:
```bash
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
```

**What it does**:
- Applies coordinate transformation matrix to touch devices
- Constrains touch input to specific display boundaries
- **Operates on DISPLAY=:0** (host X server)

**Why it's working correctly**:
- Touch coordinates ARE properly transformed
- Pointer cursor DOES move to correct location
- This function is NOT the problem

---

#### 2. `/home/pi/010_xephyr.sh` (Lines 78-79)
**Function**: Xephyr server instantiation

**Code**:
```bash
# Start Xephyr sessions
Xephyr :1 -screen "$SCR_W"x"$SCR_H"+0+0 -origin 0,0 -br -ac -noreset &
Xephyr :2 -screen "$SCR_W"x"$SCR_H"+1920+0 -origin 0,0 -br -ac -noreset &
```

**What it does**:
- Launches two nested X servers
- `-screen WxH+X+Y`: Sets virtual screen size and position on host
- `-origin 0,0`: Sets the screen origin
- `-br`: Black root window
- `-ac`: Disable access control
- `-noreset`: Don't terminate when last client exits

**Why this IS the problem**:
- No XInput2 forwarding flags
- No touch event configuration
- Standard Xephyr does not forward touch events

**Missing options** (that don't exist in standard Xephyr):
- No `-xinput2` flag
- No `-touch` flag
- No mechanism to forward XInput2 events

---

#### 3. `/home/pi/010_xephyr.sh` (Lines 86-106)
**Function**: Chromium browser instantiation

**Code**:
```bash
DISPLAY=:1 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-1 \
  --window-position=0,0 \
  --window-size="$SCR_W","$CHR_H" \
  --noerrdialogs \
  --disable-infobars \
  --incognito \
  --app="$URL_01" &

DISPLAY=:2 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-2 \
  --window-position=0,0 \
  --window-size="$SCR_W","$CHR_H" \
  --noerrdialogs \
  --disable-infobars \
  --incognito \
  --app="$URL_02" &
```

**What it does**:
- Launches Chromium browsers on nested X servers
- Each gets separate profile directory
- Fullscreen app mode for kiosk

**Why this contributes to the problem**:
- `DISPLAY=:1` and `DISPLAY=:2` connect to nested servers
- Chromium can only receive events that Xephyr forwards
- Chromium's touch scrolling features are disabled because no touch events arrive

**Missing flags** (that won't help because events aren't available):
- `--touch-events=enabled` (would have no effect - no touch events to receive)
- `--enable-features=TouchpadOverscrollHistoryNavigation`

---

### Files Indirectly Involved

#### 4. `/home/pi/lib/touchscreen-setup.sh` (Lines 150-177)
**Function**: `create_mpx_pointers()`

Creates independent master pointers for Multi-Pointer X. This works correctly and is not the cause of scrolling issues.

#### 5. `/home/pi/lib/touchscreen-setup.sh` (Lines 180-199)
**Function**: `attach_devices_to_pointers()`

Attaches touch devices to MPX pointers. This works correctly and enables independent cursors.

#### 6. `/boot/firmware/kiosk_config.sh` (Lines 28, 39-42)
**Configuration**: Touch device pattern and logging

```bash
TOUCHSCREEN_PATTERN="Weida Hi-Tech.*CoolTouchR System"
TOUCHSCREEN_LOG_LEVEL=2
TOUCHSCREEN_LOG="/var/log/kiosk/touchscreen.log"
```

Configuration is correct but cannot solve the Xephyr forwarding issue.

---

## Why Current Behavior Occurs

### What Works ✓

1. **Touch device detection**: Successfully finds both touchscreens
2. **MPX pointer creation**: Two independent cursors exist
3. **Device attachment**: Each touch device controls one cursor
4. **Coordinate mapping**: Touch coordinates correctly map to displays
5. **Pointer motion**: Touching screen moves the correct cursor
6. **Click events**: Tapping registers as mouse clicks
7. **Display isolation**: Left/right screens are independent

### What Doesn't Work ✗

1. **Touch scrolling**: Single-finger drag doesn't scroll content
2. **Flick gestures**: Quick swipes don't create momentum scrolling
3. **Two-finger scroll**: Multi-touch gestures not recognized
4. **Pinch zoom**: Zoom gestures don't work
5. **Touch feedback**: Visual feedback for touch may be missing

### Why the Mouse Scrollbar Works

When users click and drag the scrollbar:
1. Touch generates pointer motion event
2. Xephyr forwards pointer motion (core event)
3. Chromium receives pointer at scrollbar coordinates
4. Scrollbar drag is traditional mouse interaction
5. This uses core X protocol, not XInput2 extension
6. **Result**: Works, but requires precise targeting of scrollbar

---

## Solution Proposals

### Option 1: Run Chromium Directly on Host X Server (RECOMMENDED)

**Approach**: Eliminate Xephyr, run browsers directly on DISPLAY=:0

**Implementation**:
```bash
# In 010_xephyr.sh, replace Xephyr + Chromium with:

# Configure displays
xrandr --output HDMI-1 --mode 1920x1080 --pos 0x0 --rotate "$ORIENTATION" --primary
xrandr --output HDMI-2 --mode 1920x1080 --pos 1920x0 --rotate "$ORIENTATION"

# Setup touchscreens (existing code)
setup_touchscreens_mpx

# Launch browsers directly on host with window positioning
DISPLAY=:0 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-1 \
  --window-position=0,0 \
  --window-size=1080,1920 \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --app="$URL_01" &

DISPLAY=:0 chromium \
  --user-data-dir=/home/pi/.config/chrome-profile-2 \
  --window-position=1920,0 \
  --window-size=1080,1920 \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --app="$URL_02" &

# Configure OpenBox to position windows on correct displays
# Add window rules to /etc/xdg/openbox/rc.xml
```

**OpenBox Configuration** (`/etc/xdg/openbox/rc.xml`):
```xml
<applications>
  <application name="chrome-profile-1">
    <position force="yes">
      <x>0</x>
      <y>0</y>
      <monitor>1</monitor>
    </position>
    <maximized>vertical horizontal</maximized>
    <decor>no</decor>
    <layer>above</layer>
  </application>

  <application name="chrome-profile-2">
    <position force="yes">
      <x>1920</x>
      <y>0</y>
      <monitor>2</monitor>
    </position>
    <maximized>vertical horizontal</maximized>
    <decor>no</decor>
    <layer>above</layer>
  </application>
</applications>
```

**Advantages**:
- ✓ Touch scrolling will work immediately
- ✓ All XInput2 events available to Chromium
- ✓ Simpler architecture, fewer moving parts
- ✓ Better performance (no nested X server overhead)
- ✓ Existing MPX setup still provides independent cursors

**Disadvantages**:
- ✗ Browsers share same X server (but separate profiles)
- ✗ Window manager must handle positioning (OpenBox can do this)
- ✗ Requires modifying OpenBox configuration

**Difficulty**: Medium
**Likelihood of Success**: 95%

---

### Option 2: Use Xwayland Instead of Xephyr

**Approach**: Replace Xephyr with Wayland compositor and Xwayland

**Implementation**:
```bash
# Install required packages
sudo apt install weston xwayland

# Create separate Wayland sessions for each display
weston --output-count=1 --backend=drm-backend.so --seat=seat-left &
weston --output-count=1 --backend=drm-backend.so --seat=seat-right &

# Launch Chromium with Wayland native support
WAYLAND_DISPLAY=wayland-0 chromium \
  --enable-features=UseOzonePlatform \
  --ozone-platform=wayland \
  --user-data-dir=/home/pi/.config/chrome-profile-1 \
  --app="$URL_01" &
```

**Advantages**:
- ✓ Native touch support in Wayland
- ✓ Modern display protocol
- ✓ Better touch gesture handling
- ✓ Proper display isolation

**Disadvantages**:
- ✗ Major architectural change
- ✗ Multi-seat Wayland configuration is complex
- ✗ May require custom compositor configuration
- ✗ Raspberry Pi Wayland support varies by model
- ✗ MPX doesn't exist in Wayland (different multi-seat approach)

**Difficulty**: High
**Likelihood of Success**: 60%

---

### Option 3: Patch Xephyr for XInput2 Forwarding

**Approach**: Modify Xephyr source code to forward touch events

**Implementation**:
```bash
# Download Xephyr source
sudo apt install xorg-dev
apt source xserver-xephyr

# Modify input handling code to forward XInput2 events
# Edit xserver/hw/kdrive/ephyr/ephyr.c
# Add XInput2 event forwarding in input event handler

# Recompile and install custom Xephyr
./configure --enable-kdrive --enable-xephyr
make
sudo make install
```

**Required Code Changes**:
1. Add XInput2 extension initialization in Xephyr
2. Forward touch begin/update/end events
3. Maintain touch point tracking across server boundary
4. Transform coordinates for nested display

**Advantages**:
- ✓ Keeps existing architecture
- ✓ Proper touch event forwarding
- ✓ Would work for other applications too

**Disadvantages**:
- ✗ Requires C programming and X server knowledge
- ✗ Maintaining custom Xephyr build
- ✗ Updates would require rebuilding
- ✗ Complex coordinate transformation logic

**Difficulty**: Very High
**Likelihood of Success**: 40%

---

### Option 4: Use Input Device Redirection

**Approach**: Directly map touch devices to nested X servers

**Implementation**:
```bash
# After starting Xephyr servers, reassign input devices
# This requires Xephyr to have its own input drivers

# Set environment to allow device access
export XORG_DEVICE_ALLOW_NESTED=1

# Start Xephyr with direct input device access
Xephyr :1 -screen 1080x1920 \
  -keybd evdev,,device=/dev/input/by-id/keyboard-device \
  -mouse evdev,,device=/dev/input/by-id/touchscreen-1 \
  -config /etc/X11/xephyr-touch-1.conf &

Xephyr :2 -screen 1080x1920 \
  -mouse evdev,,device=/dev/input/by-id/touchscreen-2 \
  -config /etc/X11/xephyr-touch-2.conf &
```

**Configuration File Example**:
```
# /etc/X11/xephyr-touch-1.conf
Section "InputClass"
    Identifier "Touchscreen 1"
    MatchDevicePath "/dev/input/by-id/usb-Weida_Hi-Tech_CoolTouchR_System-event-if00"
    Driver "evdev"
    Option "TransformationMatrix" "0.5 0 0 0 1 0 0 0 1"
EndSection
```

**Advantages**:
- ✓ Each Xephyr gets direct touch events
- ✓ Touch events processed natively
- ✓ Maintains Xephyr architecture

**Disadvantages**:
- ✗ Xephyr may not support evdev input directly
- ✗ Permission issues accessing /dev/input
- ✗ Coordinate transformation becomes more complex
- ✗ May conflict with host X server's input handling

**Difficulty**: High
**Likelihood of Success**: 30%

---

### Option 5: Browser-Level Touch Emulation

**Approach**: Use Chromium flags to emulate touch from mouse events

**Implementation**:
```bash
# Add flags to Chromium launch
DISPLAY=:1 chromium \
  --touch-events=enabled \
  --force-device-scale-factor=1 \
  --enable-features=TouchpadOverscrollHistoryNavigation \
  --user-data-dir=/home/pi/.config/chrome-profile-1 \
  --app="$URL_01" &
```

**JavaScript injection** to convert pointer events to touch:
```javascript
// Create userscript or extension
// Inject into page via Chromium flags:
--load-extension=/home/pi/touch-emulation-extension
```

**Advantages**:
- ✓ No system changes required
- ✓ Quick to test
- ✓ Can be fine-tuned per website

**Disadvantages**:
- ✗ Won't actually work - no touch events are received
- ✗ Can only work with events that Chromium receives
- ✗ Mouse drag != touch scroll gesture
- ✗ Hacky and incomplete solution

**Difficulty**: Medium
**Likelihood of Success**: 5% (won't solve root cause)

---

## Recommended Solution Path

### Phase 1: Quick Verification (1 hour)

**Goal**: Confirm root cause by testing Chromium directly on :0

```bash
# SSH into Raspberry Pi
# Kill existing Xephyr sessions
pkill -f Xephyr
pkill -f chromium

# Launch one Chromium directly on host X server
DISPLAY=:0 chromium \
  --window-position=0,0 \
  --window-size=1080,1920 \
  --user-data-dir=/tmp/test-profile \
  --app="https://example.com" &

# Test touch scrolling on left screen
# If scrolling works → root cause confirmed
# If scrolling doesn't work → other issue exists
```

### Phase 2: Implement Solution 1 (4-8 hours)

**Step 1**: Backup current configuration
```bash
cp /home/pi/010_xephyr.sh /home/pi/010_xephyr.sh.backup
cp /etc/xdg/openbox/rc.xml /etc/xdg/openbox/rc.xml.backup
```

**Step 2**: Modify `/home/pi/010_xephyr.sh`
- Remove Xephyr startup commands
- Change Chromium DISPLAY from :1/:2 to :0
- Adjust window positioning to absolute coordinates
- Add --kiosk flag for full-screen

**Step 3**: Configure OpenBox window rules
- Add application-specific positioning rules
- Ensure windows stay on correct displays
- Remove window decorations

**Step 4**: Test and verify
- Reboot system
- Verify both browsers launch on correct displays
- Test touch scrolling on both screens
- Verify independent cursor behavior
- Test website navigation

**Step 5**: Document changes
- Update README with new architecture
- Update SETUP_INSTRUCTIONS.md
- Note removal of Xephyr dependency

### Phase 3: Polish and Optimize (2-4 hours)

- Ensure windows can't be moved between displays
- Add error handling for window positioning failures
- Create diagnostic script to verify touch events reach Chromium
- Update logging to track touch event delivery

---

## Testing Strategy

### Test 1: Verify Touch Events on Host X Server

```bash
# Check if touch events are generated on DISPLAY=:0
DISPLAY=:0 xinput test-xi --root

# Touch each screen and verify events appear
# Look for "TouchBegin", "TouchUpdate", "TouchEnd" events
```

**Expected Result**: Touch events visible with device IDs and coordinates

### Test 2: Verify Touch Events in Xephyr

```bash
# Check if touch events reach nested X server
DISPLAY=:1 xinput test-xi --root

# Touch left screen
# If no touch events appear → confirms Xephyr doesn't forward them
```

**Expected Result**: Only pointer motion events, no touch events

### Test 3: Test Direct Chromium Touch

```bash
# Launch Chromium on host X server
DISPLAY=:0 chromium --app="https://example.com/long-page" &

# Open DevTools (if accessible via physical keyboard: F12)
# Go to Console and test:
document.addEventListener('touchstart', e => console.log('Touch:', e));

# Touch the screen
# Check if console logs "Touch: TouchEvent"
```

**Expected Result**:
- On DISPLAY=:0 → Touch events logged
- On DISPLAY=:1/2 → No touch events, only mouse events

---

## Diagnostic Commands

### Check Current Configuration

```bash
# View running X servers
ps aux | grep X

# List Xephyr processes and their displays
ps aux | grep Xephyr

# View xinput device configuration
DISPLAY=:0 xinput list --long

# Check coordinate transformation matrices
DISPLAY=:0 xinput list-props <device_id>

# Monitor touch events in real-time
DISPLAY=:0 xinput test-xi --root
```

### Check Chromium Touch Support

```bash
# Check if Chromium has touch events enabled
DISPLAY=:0 chromium --disable-gpu --headless \
  --dump-dom https://example.com 2>&1 | grep -i touch

# Check Chromium flags
DISPLAY=:0 chromium --version
DISPLAY=:0 chromium --list-features | grep -i touch
```

### Verify XInput2 Extension

```bash
# Check X server extensions
DISPLAY=:0 xdpyinfo | grep -i input

# Should show: XInputExtension version 2.2 or later
```

---

## Additional Resources

### Relevant X.Org Documentation
- XInput2 Protocol: https://www.x.org/releases/X11R7.7/doc/inputproto/XI2proto.txt
- Multi-touch Documentation: https://www.x.org/wiki/Development/Documentation/Multitouch/

### Related Discussions
- Xephyr Touch Input (2014): https://lists.x.org/archives/xorg-devel/2014-September/043872.html
- Chromium Touch Events: https://www.chromium.org/developers/design-documents/touch-event-handling/

### Tools for Testing
```bash
# Install testing tools
sudo apt install xinput evtest input-utils

# Test raw input events
sudo evtest /dev/input/event0

# Monitor all input events
sudo cat /dev/input/mice | xxd
```

---

## Conclusion

The touchscreen scrolling issue is caused by **Xephyr's lack of XInput2 touch event forwarding**. Touch devices are correctly configured on the host X server, but these events cannot reach Chromium running in nested Xephyr displays.

**The most practical solution** is to eliminate Xephyr and run Chromium browsers directly on DISPLAY=:0 with window positioning managed by OpenBox. This preserves the dual-independent-cursor functionality provided by Multi-Pointer X while enabling full touch support.

**Estimated implementation time**: 6-12 hours including testing

**Confidence in solution**: 95% - This is a well-understood architectural limitation with a proven workaround.

---

*Report generated: 2025-10-29*
*System: Raspberry Pi Dual-Kiosk v2.0*
*Issue: Touch scrolling not working in Chromium browsers*
