#!/bin/bash
# Auto-Start Setup Script for Dual-Kiosk System
# Run this on the Raspberry Pi to configure automatic kiosk startup

set -e

echo "=========================================="
echo "DUAL-KIOSK AUTO-START SETUP"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo "ERROR: Do not run this script as root/sudo"
   echo "Run as: bash setup_auto_start.sh"
   exit 1
fi

# Step 1: Install unclutter
echo "Step 1: Installing unclutter for cursor hiding..."
if ! command -v unclutter &> /dev/null; then
    sudo apt update
    sudo apt install -y unclutter
    echo "  ✓ unclutter installed"
else
    echo "  ✓ unclutter already installed"
fi
echo ""

# Step 2: Check if .profile exists
echo "Step 2: Checking .profile configuration..."
if [ -f "$HOME/.profile" ]; then
    # Check if it already has kiosk start
    if grep -q "010_xephyr.sh" "$HOME/.profile"; then
        echo "  ✓ .profile already configured for kiosk"
    else
        echo "  ⚠ .profile exists but doesn't have kiosk configuration"
        echo "    Backing up existing .profile..."
        cp "$HOME/.profile" "$HOME/.profile.backup.$(date +%Y%m%d-%H%M%S)"
        echo "  ✓ Backup created"
    fi
else
    echo "  ℹ .profile not found (will be created during deployment)"
fi
echo ""

# Step 3: Check if scripts exist
echo "Step 3: Checking kiosk scripts..."
if [ -f "$HOME/010_xephyr.sh" ]; then
    echo "  ✓ 010_xephyr.sh found"
    if [ -x "$HOME/010_xephyr.sh" ]; then
        echo "  ✓ 010_xephyr.sh is executable"
    else
        echo "  ⚠ Making 010_xephyr.sh executable..."
        chmod +x "$HOME/010_xephyr.sh"
        echo "  ✓ Done"
    fi
else
    echo "  ✗ 010_xephyr.sh NOT FOUND"
    echo "    Please copy it from repository first:"
    echo "    scp rootfs/home/pi/010_xephyr.sh pi@<pi-ip>:/home/pi/"
fi

if [ -f "$HOME/010_run_xephyr.sh" ]; then
    echo "  ✓ 010_run_xephyr.sh found"
    if [ -x "$HOME/010_run_xephyr.sh" ]; then
        echo "  ✓ 010_run_xephyr.sh is executable"
    else
        echo "  ⚠ Making 010_run_xephyr.sh executable..."
        chmod +x "$HOME/010_run_xephyr.sh"
        echo "  ✓ Done"
    fi
else
    echo "  ⚠ 010_run_xephyr.sh not found (optional)"
fi
echo ""

# Step 4: Check user groups
echo "Step 4: Checking user permissions..."
REQUIRED_GROUPS=("video" "input")
MISSING_GROUPS=()

for group in "${REQUIRED_GROUPS[@]}"; do
    if groups | grep -q "\b$group\b"; then
        echo "  ✓ User in '$group' group"
    else
        echo "  ✗ User NOT in '$group' group"
        MISSING_GROUPS+=("$group")
    fi
done

if [ ${#MISSING_GROUPS[@]} -gt 0 ]; then
    echo ""
    echo "  Adding user to required groups..."
    for group in "${MISSING_GROUPS[@]}"; do
        sudo usermod -a -G "$group" "$USER"
        echo "  ✓ Added to '$group' group"
    done
    echo ""
    echo "  ⚠ You will need to log out and back in for group changes to take effect"
fi
echo ""

# Step 5: Configure auto-login
echo "Step 5: Configuring console auto-login..."

# Check if already configured
if sudo systemctl status getty@tty1.service 2>/dev/null | grep -q "autologin $USER"; then
    echo "  ✓ Console auto-login already configured"
else
    echo "  Configuring auto-login..."

    # Create systemd drop-in directory
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/

    # Create auto-login configuration
    sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF

    # Reload systemd
    sudo systemctl daemon-reload

    # Enable service
    sudo systemctl enable getty@tty1.service

    echo "  ✓ Auto-login configured for user: $USER"
fi
echo ""

# Step 6: Summary
echo "=========================================="
echo "SETUP SUMMARY"
echo "=========================================="
echo ""
echo "✓ unclutter installed (cursor hiding)"
echo "✓ Console auto-login configured"
echo "✓ User permissions verified"
echo ""

if [ -f "$HOME/010_xephyr.sh" ]; then
    echo "Next steps:"
    echo "1. Copy .profile to /home/pi/ if not already done:"
    echo "   scp rootfs/home/pi/.profile pi@<pi-ip>:/home/pi/"
    echo ""
    echo "2. Reboot the Raspberry Pi:"
    echo "   sudo reboot"
    echo ""
    echo "3. Kiosk should start automatically"
    echo "   - Cursors will be hidden"
    echo "   - Touch input will work"
    echo "   - Both displays should show content"
else
    echo "⚠ IMPORTANT:"
    echo "   You still need to copy the kiosk scripts:"
    echo "   1. scp rootfs/home/pi/.profile pi@<pi-ip>:/home/pi/"
    echo "   2. scp rootfs/home/pi/010_xephyr.sh pi@<pi-ip>:/home/pi/"
    echo ""
    echo "   Then reboot: sudo reboot"
fi
echo ""
echo "=========================================="
echo "SETUP COMPLETE"
echo "=========================================="
