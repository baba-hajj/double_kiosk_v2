# Keyboard & Password Solution Plan

## Problem Summary

After removing Xephyr and running Chromium directly on DISPLAY=:0:
1. ✗ USB keyboard input not working
2. ✗ Password field needs auto-fill for "iheartjane"

---

## Root Cause Analysis: Keyboard Issue

### Multi-Pointer X (MPX) Keyboard Behavior

When `create_mpx_pointers()` runs, it creates:
```
xinput create-master "Kiosk1"
  → Creates: "Kiosk1 pointer" + "Kiosk1 keyboard"

xinput create-master "Kiosk2"
  → Creates: "Kiosk2 pointer" + "Kiosk2 keyboard"
```

**The problem**:
- MPX keyboard focus follows pointer focus
- Physical keyboard might be on "Virtual core keyboard"
- When touch moves "Kiosk1 pointer" into Browser 1, that browser expects input from "Kiosk1 keyboard"
- Physical keyboard on "Virtual core keyboard" can't send input to a window expecting "Kiosk1 keyboard"

**Why it worked with Xephyr**:
- Each Xephyr nested server had independent input routing
- Keyboard events were forwarded to whichever Xephyr window had focus
- No MPX keyboard confusion in nested servers

**Why it fails now**:
- Both browsers on same X server with MPX active
- Keyboard focus tied to pointer device hierarchy
- Physical keyboard not connected to the right master device

---

## Proposed Solutions

### Option 1: Replicate Keyboard to All Master Keyboards (RECOMMENDED)

**Approach**: Keep MPX for pointers, but ensure physical keyboard works in all contexts

**Implementation**:
```bash
# After MPX setup, identify physical keyboard
PHYSICAL_KB_ID=$(xinput list | grep -i "keyboard" | grep -v "Virtual\|Kiosk" | grep -oP 'id=\K\d+' | head -1)

# Create floating keyboard that can work everywhere
# OR attach to Virtual core keyboard and configure windows to accept it

# Alternative: Use xdotool or evdev to replicate keyboard input
```

**Pros**:
- ✓ Keyboard works in both browsers
- ✓ Maintains MPX pointer independence
- ✓ Clean solution

**Cons**:
- ✗ Moderate complexity
- ✗ Might need input event replication

**Confidence**: 85%

---

### Option 2: Disable MPX Keyboards (Keep MPX Pointers Only)

**Approach**: Modify MPX setup to prevent keyboard master device conflicts

**Implementation**: Modify `touchscreen-setup.sh` to:
1. Create MPX master pointers as usual
2. Attach touch devices to master pointers
3. Keep ALL keyboards on "Virtual core keyboard"
4. Ensure windows accept input from Virtual core keyboard

**Code change in `create_mpx_pointers()`**:
```bash
# After creating masters, reattach all keyboards to Virtual core
KEYBOARD_IDS=$(xinput list | grep -i keyboard | grep "slave" | grep -oP 'id=\K\d+')
for kb_id in $KEYBOARD_IDS; do
    xinput reattach "$kb_id" "Virtual core keyboard" 2>/dev/null || true
done
```

**Pros**:
- ✓ Simple to implement
- ✓ Maintains pointer independence
- ✓ All keyboards work uniformly

**Cons**:
- ✗ May not solve focus issue if windows only listen to their master keyboards
- ✗ Partially defeats MPX purpose

**Confidence**: 70%

---

### Option 3: Focus Management Fix

**Approach**: Ensure both Chromium windows accept keyboard input from any master keyboard

**Implementation**:
```bash
# Set window properties to accept input from all devices
DISPLAY=:0 xdotool search --class "Chromium" set_window --urgency 1

# Or use OpenBox configuration to manage focus
# Edit /etc/xdg/openbox/rc.xml to set focusLast=yes
```

**Pros**:
- ✓ No MPX changes needed
- ✓ Quick to test

**Cons**:
- ✗ May not fully solve the issue
- ✗ Doesn't address root cause

**Confidence**: 60%

---

### Option 4: Simplify MPX - Remove Master Keyboards

**Approach**: Only create master pointers, not master keyboards (if possible)

**Investigation needed**: Check if `xinput create-master` can create pointer-only masters

**Pros**:
- ✓ Would cleanly solve keyboard issue
- ✓ Maintains pointer independence

**Cons**:
- ✗ May not be possible (MPX typically creates pairs)
- ✗ Unknown if xinput supports this

**Confidence**: 40% (needs investigation)

---

## Password Auto-Fill Solutions

### Option A: Chromium User Data with Saved Password (RECOMMENDED)

**Approach**: Use Chromium's built-in password manager

**Implementation**:
```bash
# 1. On first run, manually log in once and save password
# 2. Chromium will auto-fill on subsequent loads

# OR: Pre-populate the password store
# Create a script to inject saved password into Chrome profile
```

**Pros**:
- ✓ Native Chromium feature
- ✓ Persistent across reboots
- ✓ Secure (passwords encrypted)

**Cons**:
- ✗ Requires initial manual login
- ✗ Password stored in profile

**Confidence**: 95%

---

### Option B: JavaScript Injection via Chromium Extension

**Approach**: Create a minimal Chrome extension to auto-fill password

**Implementation**:
```javascript
// manifest.json
{
  "name": "Kiosk Autofill",
  "version": "1.0",
  "manifest_version": 3,
  "content_scripts": [{
    "matches": ["https://kiosk.iheartjane.com/*"],
    "js": ["autofill.js"],
    "run_at": "document_idle"
  }]
}

// autofill.js
const passwordField = document.querySelector('#password');
if (passwordField && !passwordField.value) {
  passwordField.value = 'iheartjane';
  passwordField.dispatchEvent(new Event('input', { bubbles: true }));

  // Auto-submit if form exists
  const form = passwordField.closest('form');
  if (form) {
    setTimeout(() => form.submit(), 500);
  }
}
```

**Launch Chromium with**:
```bash
--load-extension=/home/pi/kiosk-autofill-extension
```

**Pros**:
- ✓ Guaranteed to work
- ✓ Can auto-submit form
- ✓ Easy to modify

**Cons**:
- ✗ Need to create and maintain extension
- ✗ Password visible in extension code

**Confidence**: 99%

---

### Option C: User Script Injection via Chromium Flags

**Approach**: Inject JavaScript directly without extension

**Implementation**:
```bash
# Create autofill script
cat > /home/pi/kiosk-autofill.js << 'EOF'
(function() {
  window.addEventListener('load', () => {
    setTimeout(() => {
      const pw = document.querySelector('#password');
      if (pw && !pw.value) {
        pw.value = 'iheartjane';
        pw.dispatchEvent(new Event('input', { bubbles: true }));
        pw.dispatchEvent(new Event('change', { bubbles: true }));
      }
    }, 1000);
  });
})();
EOF

# Launch Chromium with injection
--user-script=/home/pi/kiosk-autofill.js
```

**Pros**:
- ✓ Simpler than extension
- ✓ No manifest needed

**Cons**:
- ✗ --user-script flag might not work in kiosk mode
- ✗ Limited browser support for this flag

**Confidence**: 60%

---

### Option D: Bookmarklet Auto-Login URL

**Approach**: Create a modified URL that includes credentials

**Implementation**:
```bash
# If the site supports URL parameters for login
URL_01="https://kiosk.iheartjane.com/stores/6610/landing?auto_login=true"

# Or use a bookmarklet approach
# This is site-specific and may not work
```

**Pros**:
- ✓ Very simple
- ✓ No code needed

**Cons**:
- ✗ Site must support this
- ✗ Credentials in URL (security concern)
- ✗ Unlikely to work

**Confidence**: 20%

---

## Recommended Implementation Plan

### Phase 1: Fix Keyboard (Priority 1)
**Recommended: Option 1 + Option 2 hybrid**

1. **Run diagnostic** to understand current state:
   ```bash
   DISPLAY=:0 bash diagnose_keyboard.sh > keyboard_diagnostic.txt
   ```

2. **Implement keyboard fix** in `touchscreen-setup.sh`:
   - After MPX setup, identify physical keyboard
   - Ensure it's accessible from all contexts
   - May need to replicate input or adjust focus management

3. **Test keyboard** in both browsers:
   ```bash
   # Click in browser 1, type
   # Click in browser 2, type
   # Both should work
   ```

**Estimated time**: 1-2 hours
**Fallback**: If MPX keyboard issues persist, consider disabling MPX entirely and using simple xinput mapping (losing independent cursors but gaining keyboard)

---

### Phase 2: Auto-Fill Password (Priority 2)
**Recommended: Option B (Chrome Extension)**

1. **Create extension**:
   ```bash
   mkdir -p /home/pi/kiosk-autofill-extension
   # Create manifest.json and autofill.js
   ```

2. **Modify Chromium launch** in `010_xephyr.sh`:
   ```bash
   --load-extension=/home/pi/kiosk-autofill-extension
   ```

3. **Test auto-fill**:
   - Load page
   - Verify password field populated
   - Optionally: Auto-submit form

**Estimated time**: 30 minutes - 1 hour
**Alternative**: Option A (save password in Chromium profile) - simpler but requires one-time manual login

---

## Decision Matrix

| Solution | Complexity | Reliability | Security | Time |
|----------|-----------|-------------|----------|------|
| **Keyboard Option 1** | Medium | High | Good | 1-2h |
| **Keyboard Option 2** | Low | Medium | Good | 1h |
| **Password Option B (Extension)** | Low | Very High | Medium | 30m |
| **Password Option A (Saved)** | Very Low | High | Good | 10m |

---

## Recommended Approach

### Step 1: Diagnose (15 minutes)
- Run `diagnose_keyboard.sh` on Raspberry Pi
- Understand current MPX keyboard configuration
- Identify which master keyboard has the physical USB keyboard

### Step 2: Fix Keyboard (1-2 hours)
**If keyboard is on Virtual core keyboard**:
- Modify MPX to ensure Virtual core keyboard can interact with both browsers
- Adjust focus management

**If keyboard is on Kiosk1/Kiosk2 keyboard**:
- Reattach physical keyboard to Virtual core
- Ensure both browsers accept Virtual core keyboard input

**If MPX keyboard conflicts are unsolvable**:
- Consider simplifying to single pointer with mapped touchscreens (lose independent cursors)
- Or use input event replication

### Step 3: Add Password Auto-Fill (30 minutes)
**Recommended: Chrome extension (Option B)**
- Most reliable
- Easy to maintain
- Can auto-submit

**Alternative: Saved password (Option A)**
- Simpler
- Requires one-time setup
- Uses native Chromium feature

---

## Testing Checklist

### Keyboard Testing
- [ ] USB keyboard detected by system
- [ ] Keyboard works in browser 1
- [ ] Keyboard works in browser 2
- [ ] Keyboard works after touching screen
- [ ] Both cursors still work independently

### Password Auto-Fill Testing
- [ ] Page loads
- [ ] Password field auto-fills
- [ ] Can still manually type if needed
- [ ] Works on both browsers
- [ ] Works after reboot

---

## Security Considerations

1. **Password in Extension**: The password "iheartjane" will be visible in extension code
   - Acceptable for kiosk use case
   - Not suitable for sensitive passwords

2. **Saved Password in Profile**: Chromium encrypts stored passwords
   - More secure than plaintext
   - Requires system access to extract

3. **Recommendation**: For a public kiosk, extension is fine. For private/sensitive use, prefer saved password option.

---

## Next Steps

**Awaiting your approval to proceed with**:
1. Run keyboard diagnostic
2. Implement keyboard fix (based on diagnostic results)
3. Implement password auto-fill (Chrome extension)

**Estimated total time**: 2-3 hours
**Expected outcome**:
- ✓ USB keyboard works in both browsers
- ✓ Password auto-fills on page load
- ✓ Independent cursors still work
- ✓ Touch scrolling still works

---

**Created**: 2025-10-29
**Status**: Awaiting approval to implement
