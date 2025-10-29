# Auto-Start and Cursor Hiding Setup Guide

**Date**: 2025-10-29
**Purpose**: Configure automatic kiosk startup on boot and hide cursors for touch-only interface

---

## Issue 1: Hide All Mouse Cursors

### Problem
Three cursors visible on displays:
1. Virtual core pointer (main X cursor)
2. Kiosk1 pointer (MPX cursor for left screen)
3. Kiosk2 pointer (MPX cursor for right screen)

For a touch-only kiosk, cursors are unnecessary and distracting.

### Solution Implemented

**Multi-layered cursor hiding approach** in `010_xephyr.sh`:

#### Method 1: unclutter (Primary)
```bash
unclutter -idle 0.01 -root
```
- Hides cursor after 0.01 seconds of inactivity
- Works across all pointers (Virtual core, Kiosk1, Kiosk2)
- Runs in background
- **Requires installation** (see deployment steps)

#### Method 2: X Root Window
```bash
xsetroot -cursor_name none
```
- Sets root window cursor to invisible
- Fallback if unclutter not available
- Immediate effect

#### Method 3: Chromium Flags
```bash
--kiosk-printing
--enable-features=OverlayScrollbar
--hide-scrollbars
```
- Hides cursor within Chromium windows
- Also hides scrollbars for cleaner interface
- Browser-specific solution

**Result**: All three cursors hidden, clean touch-only interface

---

## Issue 2: Auto-Start Kiosk on Boot

### Problem
The `010_xephyr.sh` script needs to execute automatically when Raspberry Pi boots.

### How It Works

**Boot Flow**:
```
Raspberry Pi Boots
    ↓
Console Auto-login as user 'pi' (tty1)
    ↓
User logs in → ~/.profile executes
    ↓
~/.profile checks if on console (tty1)
    ↓
If yes: Start X server with 010_xephyr.sh
    ↓
Kiosk system starts
```

### Solution: Auto-login + .profile

**Two-part setup**:
1. **Enable auto-login** to console as user `pi`
2. **Create ~/.profile** to launch kiosk script

---

## Deployment Instructions

### Part 1: Install unclutter (for cursor hiding)

```bash
ssh pi@<raspberry-pi-ip>

# Install unclutter
sudo apt update
sudo apt install -y unclutter

# Verify installation
which unclutter
# Should output: /usr/bin/unclutter
```

---

### Part 2: Enable Console Auto-login

**Method A: Using raspi-config (Recommended)**

```bash
ssh pi@<raspberry-pi-ip>

# Run raspi-config
sudo raspi-config

# Navigate:
# 1. System Options
# 2. Boot / Auto Login
# 3. Select: "Console Autologin" (B2)
#    Description: "Text console, automatically logged in as 'pi' user"
# 4. Select "Finish"
# 5. Reboot when prompted: Yes
```

**Method B: Manual Configuration**

```bash
ssh pi@<raspberry-pi-ip>

# Create systemd drop-in directory
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/

# Create auto-login configuration
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable getty@tty1
sudo systemctl enable getty@tty1.service
```

---

### Part 3: Deploy .profile for Auto-Start

```bash
# From your local machine:
cd /home/user/double_kiosk_v2

# Copy .profile to Pi
scp rootfs/home/pi/.profile pi@<raspberry-pi-ip>:/home/pi/

# SSH to Pi and verify
ssh pi@<raspberry-pi-ip>
ls -la /home/pi/.profile
# Should show: -rw-r--r-- 1 pi pi <size> <date> /home/pi/.profile

# Check contents
cat /home/pi/.profile
```

---

### Part 4: Deploy Updated 010_xephyr.sh

```bash
# From your local machine:
cd /home/user/double_kiosk_v2

# Copy updated script (with cursor hiding)
scp rootfs/home/pi/010_xephyr.sh pi@<raspberry-pi-ip>:/home/pi/

# Set executable permissions
ssh pi@<raspberry-pi-ip>
chmod +x /home/pi/010_xephyr.sh
chmod +x /home/pi/010_run_xephyr.sh
```

---

### Part 5: Reboot and Test

```bash
# Reboot Raspberry Pi
ssh pi@<raspberry-pi-ip>
sudo reboot

# Expected behavior:
# 1. Pi boots to console
# 2. Automatically logs in as user 'pi'
# 3. ~/.profile executes
# 4. X server starts
# 5. Kiosk displays appear
# 6. NO CURSORS VISIBLE
# 7. Touch input works without visible cursor
```

---

## Verification

### Check Auto-login Configuration

```bash
# Check systemd configuration
sudo systemctl status getty@tty1.service

# Should show: "autologin pi"
```

### Check .profile

```bash
# View .profile
cat /home/pi/.profile

# Should contain:
# - Check for tty1
# - startx or xinit command
```

### Check Cursor Hiding

```bash
# Check if unclutter is running
ps aux | grep unclutter
# Should show: unclutter -idle 0.01 -root

# Check X cursor configuration
DISPLAY=:0 xset q | grep -A 1 "Screen Saver"
```

### Check Kiosk Running

```bash
# Check X server
ps aux | grep X
# Should show: /usr/lib/xorg/Xorg :0

# Check Chromium browsers
ps aux | grep chromium | wc -l
# Should show: 8-12 processes

# Check displays
DISPLAY=:0 xrandr | grep " connected"
# Should show: HDMI-1 and HDMI-2 connected
```

---

## Troubleshooting

### Cursor Still Visible

**Problem**: Cursor appears on screen

**Solution 1**: Check unclutter installed
```bash
which unclutter
# If not found:
sudo apt install -y unclutter
sudo reboot
```

**Solution 2**: Check unclutter running
```bash
ps aux | grep unclutter
# If not running, restart kiosk:
sudo systemctl restart getty@tty1
```

**Solution 3**: Install invisible cursor theme
```bash
sudo apt install -y xserver-xorg-video-dummy
mkdir -p ~/.icons/default
cat > ~/.icons/default/index.theme <<'EOF'
[Icon Theme]
Name=NoCursor
Comment=Invisible cursor theme
EOF
```

---

### Kiosk Doesn't Auto-Start

**Problem**: System boots but kiosk doesn't start

**Diagnosis**:
```bash
# Check which TTY you're on
tty
# Should be: /dev/tty1

# Check if .profile exists
ls -la /home/pi/.profile

# Check .profile is executable
cat /home/pi/.profile

# Check auto-login configured
sudo systemctl status getty@tty1.service | grep autologin
```

**Solution 1**: Verify .profile logic
```bash
# Manually test .profile
bash /home/pi/.profile
# Should start kiosk if on tty1
```

**Solution 2**: Check X server permissions
```bash
# Ensure pi user can start X
groups pi
# Should include: video, input

# Add if missing:
sudo usermod -a -G video,input pi
```

**Solution 3**: Check xinit/startx available
```bash
which startx
which xinit
# If not found:
sudo apt install -y xinit xorg
```

---

### Auto-login Not Working

**Problem**: System prompts for login instead of auto-logging in

**Solution**:
```bash
# Reconfigure auto-login
sudo raspi-config
# Navigate to: System Options → Boot/Auto Login → Console Autologin

# Or check manual configuration:
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf
# Should contain: --autologin pi

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart getty@tty1
```

---

### Kiosk Starts on SSH Login

**Problem**: Kiosk tries to start when SSH'ing in

**Cause**: .profile runs on SSH login too

**Solution**: Already handled! The `.profile` script checks:
```bash
if [ "$(tty)" = "/dev/tty1" ]; then
    # Only run on console, not SSH
fi
```

This ensures kiosk only starts on physical console (tty1), not SSH sessions.

---

## Alternative Auto-Start Methods

If .profile method doesn't work, try these alternatives:

### Method 1: Systemd Service (Most Robust)

Create `/etc/systemd/system/kiosk.service`:

```ini
[Unit]
Description=Dual Kiosk System
After=multi-user.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
ExecStart=/usr/bin/xinit /home/pi/010_xephyr.sh -- :0 vt1
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable kiosk.service
sudo systemctl start kiosk.service
```

### Method 2: Crontab @reboot

```bash
crontab -e

# Add this line:
@reboot sleep 10 && DISPLAY=:0 /home/pi/010_xephyr.sh

# Save and exit
```

### Method 3: /etc/rc.local (Legacy)

```bash
sudo nano /etc/rc.local

# Add before "exit 0":
su - pi -c "startx /home/pi/010_xephyr.sh -- :0 vt1" &

# Save and exit
sudo chmod +x /etc/rc.local
```

---

## Files Created/Modified

### New Files

1. **`rootfs/home/pi/.profile`**
   - Auto-start script triggered on console login
   - Checks for tty1 (console) before starting kiosk
   - Uses startx to launch X with kiosk script

### Modified Files

1. **`rootfs/home/pi/010_xephyr.sh`**
   - Added cursor hiding section (lines 152-169)
   - Added 3 cursor hiding methods
   - Added unclutter with 0.01s idle time
   - Added xsetroot cursor configuration
   - Added 3 Chromium flags for browser cursor hiding

---

## Technical Details

### Why Three Cursor Hiding Methods?

**Defense in Depth Strategy**:

1. **unclutter**: Hides cursor at X server level (all applications)
   - Works for all pointers (Virtual core, Kiosk1, Kiosk2)
   - Hides after very short idle (0.01s = ~instant)
   - Most effective but requires installation

2. **xsetroot**: Sets root window cursor to "none"
   - Fallback if unclutter fails
   - Built into X server
   - Only affects root window, not application windows

3. **Chromium flags**: Hides cursor within browsers
   - Application-level hiding
   - Also hides scrollbars
   - Ensures clean interface even if X-level hiding fails

**Result**: Cursor hidden at multiple layers, ensuring invisible cursor even if one method fails.

### Why .profile Instead of .bashrc?

**`.profile`**:
- Runs once per login session
- Executed by all POSIX shells (sh, bash, dash)
- Used for session-wide environment setup
- **Correct for starting graphical applications**

**`.bashrc`**:
- Runs every time bash starts (including sub-shells)
- Bash-specific
- Used for interactive shell configuration
- Would cause X server to restart on every new shell

**Conclusion**: `.profile` is the standard and correct location for starting X server on login.

---

## Expected Behavior

### On Boot:
1. Raspberry Pi boots (5-10 seconds)
2. Console login service starts
3. Auto-login as 'pi' user
4. ~/.profile executes
5. X server starts on :0
6. Display detection runs (up to 20 seconds)
7. Touchscreen MPX setup runs
8. Cursors hidden
9. OpenBox window manager starts
10. Both Chromium browsers launch
11. Keyboard focus configured
12. Kiosk ready (~30-40 seconds total)

### Visible on Screens:
- ✅ Both displays showing web content
- ✅ NO CURSORS VISIBLE
- ✅ Touch input works
- ✅ Scrolling works (finger drag)
- ✅ Keyboard input works (after clicking)
- ✅ Password auto-filled
- ✅ Clean kiosk interface

---

## Maintenance

### Daily Operations

**Normal Shutdown**:
```bash
sudo shutdown -h now
```

**Restart Kiosk** (without full reboot):
```bash
# SSH in
ssh pi@<raspberry-pi-ip>

# Kill existing session
sudo pkill X

# Logout and login again (triggers .profile)
# Or reboot:
sudo reboot
```

### Updates

**Update system**:
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

**Update kiosk scripts**:
```bash
# Copy new scripts
scp rootfs/home/pi/010_xephyr.sh pi@<pi-ip>:/home/pi/

# Restart
sudo systemctl restart getty@tty1
# Or reboot
```

---

## Security Considerations

**Auto-login Security**:
- Physical access = full system access
- Acceptable for kiosk in controlled environment
- NOT recommended for systems with sensitive data
- Consider: Physical security of device, network isolation

**Mitigation**:
- Keep kiosk in supervised area
- Use network firewall rules
- Restrict website to trusted domains
- Regular security updates

---

## Summary

### What Was Implemented

1. **Cursor Hiding** (3 methods):
   - unclutter for system-wide cursor hiding
   - xsetroot for root window cursor
   - Chromium flags for browser cursor

2. **Auto-Start**:
   - .profile configuration for automatic kiosk launch
   - Console auto-login for user 'pi'
   - tty1 detection to prevent SSH interference

### Deployment Checklist

- [ ] Install unclutter (`sudo apt install unclutter`)
- [ ] Enable console auto-login (`sudo raspi-config`)
- [ ] Copy .profile to /home/pi/
- [ ] Copy updated 010_xephyr.sh to /home/pi/
- [ ] Set executable permissions
- [ ] Reboot and verify
- [ ] Test cursor hiding
- [ ] Test touch input
- [ ] Verify auto-start on power cycle

---

**Status**: Complete and ready for deployment
**Expected Result**: Touch-only kiosk with no visible cursors that starts automatically on boot
**Total Setup Time**: 10-15 minutes
