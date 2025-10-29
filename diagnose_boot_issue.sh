#!/bin/bash
# Comprehensive Diagnostic for Auto-Start Issues
# Run this on Raspberry Pi: bash diagnose_boot_issue.sh

echo "=========================================="
echo "AUTO-START DIAGNOSTIC REPORT"
echo "=========================================="
echo ""

# Check 1: Display Manager Status
echo "1. DISPLAY MANAGER CHECK:"
echo "-------------------"
if systemctl is-active --quiet lightdm; then
    echo "  ✗ LightDM is RUNNING (this prevents console auto-start)"
    echo "    Status: $(systemctl is-active lightdm)"
    DISPLAY_MANAGER_RUNNING=true
elif systemctl is-active --quiet gdm; then
    echo "  ✗ GDM is RUNNING (this prevents console auto-start)"
    echo "    Status: $(systemctl is-active gdm)"
    DISPLAY_MANAGER_RUNNING=true
elif systemctl is-active --quiet sddm; then
    echo "  ✗ SDDM is RUNNING (this prevents console auto-start)"
    echo "    Status: $(systemctl is-active sddm)"
    DISPLAY_MANAGER_RUNNING=true
else
    echo "  ✓ No display manager running (good for console auto-start)"
    DISPLAY_MANAGER_RUNNING=false
fi
echo ""

# Check 2: Boot Target
echo "2. BOOT TARGET:"
echo "-------------------"
DEFAULT_TARGET=$(systemctl get-default)
echo "  Current default target: $DEFAULT_TARGET"
if [ "$DEFAULT_TARGET" = "graphical.target" ]; then
    echo "  ⚠ System boots to graphical mode"
    echo "    This may conflict with console auto-start"
elif [ "$DEFAULT_TARGET" = "multi-user.target" ]; then
    echo "  ✓ System boots to console mode (correct for kiosk)"
fi
echo ""

# Check 3: Console Auto-login Configuration
echo "3. CONSOLE AUTO-LOGIN:"
echo "-------------------"
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    echo "  ✓ Auto-login configuration file exists"
    echo "    Contents:"
    cat /etc/systemd/system/getty@tty1.service.d/autologin.conf | sed 's/^/    /'
else
    echo "  ✗ Auto-login configuration file NOT FOUND"
    echo "    Expected: /etc/systemd/system/getty@tty1.service.d/autologin.conf"
fi
echo ""

# Check 4: Getty Service Status
echo "4. GETTY SERVICE STATUS:"
echo "-------------------"
if systemctl is-active --quiet getty@tty1.service; then
    echo "  ✓ getty@tty1.service is active"
    systemctl status getty@tty1.service --no-pager | grep -E "Active:|autologin" | sed 's/^/    /'
else
    echo "  ✗ getty@tty1.service is NOT active"
fi
echo ""

# Check 5: Current TTY
echo "5. CURRENT ENVIRONMENT:"
echo "-------------------"
echo "  Current TTY: $(tty)"
echo "  Current User: $USER"
echo "  DISPLAY variable: ${DISPLAY:-not set}"
if [ -n "$DISPLAY" ]; then
    echo "  ⚠ X server already running on $DISPLAY"
fi
echo ""

# Check 6: .profile Configuration
echo "6. .PROFILE CONFIGURATION:"
echo "-------------------"
if [ -f /home/pi/.profile ]; then
    echo "  ✓ .profile exists"
    echo "    Size: $(stat -f%z /home/pi/.profile 2>/dev/null || stat -c%s /home/pi/.profile) bytes"
    echo "    Contents:"
    cat /home/pi/.profile | sed 's/^/    /'
else
    echo "  ✗ .profile NOT FOUND at /home/pi/.profile"
fi
echo ""

# Check 7: Kiosk Scripts
echo "7. KIOSK SCRIPTS:"
echo "-------------------"
if [ -f /home/pi/010_xephyr.sh ]; then
    echo "  ✓ 010_xephyr.sh exists"
    echo "    Executable: $([ -x /home/pi/010_xephyr.sh ] && echo "YES" || echo "NO")"
else
    echo "  ✗ 010_xephyr.sh NOT FOUND"
fi
echo ""

# Check 8: X Server Status
echo "8. X SERVER STATUS:"
echo "-------------------"
if pgrep -x X > /dev/null || pgrep -x Xorg > /dev/null; then
    echo "  ✓ X server is running"
    ps aux | grep -E "X |Xorg " | grep -v grep | sed 's/^/    /'
else
    echo "  ✗ X server is NOT running"
fi
echo ""

# Check 9: Chromium Status
echo "9. CHROMIUM STATUS:"
echo "-------------------"
CHROMIUM_COUNT=$(ps aux | grep chromium | grep -v grep | wc -l)
if [ $CHROMIUM_COUNT -gt 0 ]; then
    echo "  ✓ Chromium is running ($CHROMIUM_COUNT processes)"
else
    echo "  ✗ Chromium is NOT running"
fi
echo ""

# Check 10: unclutter Status
echo "10. UNCLUTTER STATUS:"
echo "-------------------"
if command -v unclutter &> /dev/null; then
    echo "  ✓ unclutter is installed: $(which unclutter)"
    if pgrep -x unclutter > /dev/null; then
        echo "  ✓ unclutter is RUNNING"
        ps aux | grep unclutter | grep -v grep | sed 's/^/    /'
    else
        echo "  ✗ unclutter is NOT running"
    fi
else
    echo "  ✗ unclutter is NOT installed"
fi
echo ""

# Check 11: Current Display Configuration
echo "11. DISPLAY CONFIGURATION:"
echo "-------------------"
if [ -n "$DISPLAY" ]; then
    DISPLAY=:0 xrandr 2>/dev/null | grep " connected" | sed 's/^/    /' || echo "  Cannot query displays"
else
    echo "  Cannot check (DISPLAY not set)"
fi
echo ""

# Summary and Recommendations
echo "=========================================="
echo "DIAGNOSIS SUMMARY"
echo "=========================================="
echo ""

if [ "$DISPLAY_MANAGER_RUNNING" = true ]; then
    echo "⚠ PRIMARY ISSUE: Display manager is running"
    echo ""
    echo "PROBLEM:"
    echo "  A display manager (lightdm/gdm/sddm) is auto-starting X server."
    echo "  This prevents console login and .profile execution."
    echo ""
    echo "SOLUTION:"
    echo "  1. Disable display manager:"
    echo "     sudo systemctl disable lightdm"
    echo "     sudo systemctl disable gdm"
    echo "     sudo systemctl disable sddm"
    echo ""
    echo "  2. Set console boot:"
    echo "     sudo systemctl set-default multi-user.target"
    echo ""
    echo "  3. Reboot:"
    echo "     sudo reboot"
    echo ""
fi

if [ ! -f /home/pi/.profile ]; then
    echo "⚠ ISSUE: .profile file missing"
    echo "  Copy it to /home/pi/.profile"
    echo ""
fi

if [ ! -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    echo "⚠ ISSUE: Console auto-login not configured"
    echo "  Run: sudo raspi-config → System Options → Boot/Auto Login"
    echo "  Or run the setup_auto_start.sh script again"
    echo ""
fi

if ! command -v unclutter &> /dev/null; then
    echo "⚠ ISSUE: unclutter not installed"
    echo "  Install: sudo apt install -y unclutter"
    echo ""
fi

echo "=========================================="
echo "RECOMMENDED ACTIONS"
echo "=========================================="
echo ""
if [ "$DISPLAY_MANAGER_RUNNING" = true ]; then
    echo "PRIORITY 1: Fix display manager conflict"
    echo "  Run these commands:"
    echo "    sudo systemctl disable lightdm"
    echo "    sudo systemctl set-default multi-user.target"
    echo "    sudo reboot"
    echo ""
fi

echo "Or use the systemd service method (more robust):"
echo "  See fix_auto_start.sh for automated solution"
echo ""
echo "=========================================="
