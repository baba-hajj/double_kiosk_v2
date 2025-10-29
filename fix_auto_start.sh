#!/bin/bash
# Comprehensive Fix for Auto-Start and Cursor Hiding Issues
# Run this on Raspberry Pi: sudo bash fix_auto_start.sh

set -e

if [ "$EUID" -ne 0 ]; then
   echo "ERROR: This script must be run as root"
   echo "Run: sudo bash fix_auto_start.sh"
   exit 1
fi

echo "=========================================="
echo "KIOSK AUTO-START FIX"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Disable any conflicting display managers"
echo "  2. Create a systemd service for kiosk"
echo "  3. Configure cursor hiding"
echo "  4. Set up automatic startup"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi
echo ""

# Step 1: Disable display managers
echo "Step 1: Checking for display managers..."
DISABLED_SOMETHING=false

for dm in lightdm gdm gdm3 sddm xdm; do
    if systemctl is-enabled --quiet $dm 2>/dev/null; then
        echo "  Disabling $dm..."
        systemctl disable $dm
        systemctl stop $dm 2>/dev/null || true
        DISABLED_SOMETHING=true
        echo "  ✓ $dm disabled"
    fi
done

if [ "$DISABLED_SOMETHING" = false ]; then
    echo "  ✓ No display managers found (good)"
fi
echo ""

# Step 2: Set console boot target
echo "Step 2: Configuring boot target..."
CURRENT_TARGET=$(systemctl get-default)
if [ "$CURRENT_TARGET" != "multi-user.target" ]; then
    echo "  Changing from $CURRENT_TARGET to multi-user.target"
    systemctl set-default multi-user.target
    echo "  ✓ Boot target set to console mode"
else
    echo "  ✓ Already set to multi-user.target"
fi
echo ""

# Step 3: Install dependencies
echo "Step 3: Installing dependencies..."
apt update -qq
apt install -y unclutter xserver-xorg xinit
echo "  ✓ Dependencies installed"
echo ""

# Step 4: Create systemd service
echo "Step 4: Creating systemd service..."

cat > /etc/systemd/system/kiosk.service <<'EOF'
[Unit]
Description=Dual Touchscreen Kiosk
After=multi-user.target
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=pi
Group=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
StandardOutput=journal
StandardError=journal
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash -c 'cd /home/pi && /usr/bin/startx /home/pi/010_xephyr.sh -- :0 vt1'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "  ✓ Service file created: /etc/systemd/system/kiosk.service"
echo ""

# Step 5: Enable the service
echo "Step 5: Enabling kiosk service..."
systemctl daemon-reload
systemctl enable kiosk.service
echo "  ✓ Kiosk service enabled"
echo ""

# Step 6: Ensure user permissions
echo "Step 6: Verifying user permissions..."
usermod -a -G video,input,tty pi 2>/dev/null || true
echo "  ✓ User 'pi' added to required groups"
echo ""

# Step 7: Make scripts executable
echo "Step 7: Setting script permissions..."
if [ -f /home/pi/010_xephyr.sh ]; then
    chmod +x /home/pi/010_xephyr.sh
    chown pi:pi /home/pi/010_xephyr.sh
    echo "  ✓ 010_xephyr.sh permissions set"
else
    echo "  ⚠ Warning: /home/pi/010_xephyr.sh not found"
    echo "    Please copy it before rebooting"
fi

if [ -f /home/pi/010_run_xephyr.sh ]; then
    chmod +x /home/pi/010_run_xephyr.sh
    chown pi:pi /home/pi/010_run_xephyr.sh
    echo "  ✓ 010_run_xephyr.sh permissions set"
fi
echo ""

# Step 8: Configure unclutter auto-start
echo "Step 8: Configuring cursor hiding..."

# Create autostart directory for OpenBox
mkdir -p /home/pi/.config/openbox
cat > /home/pi/.config/openbox/autostart <<'EOF'
# Hide cursor with unclutter
unclutter -idle 0.01 -root &
EOF

chown -R pi:pi /home/pi/.config
chmod +x /home/pi/.config/openbox/autostart

echo "  ✓ Cursor hiding configured in OpenBox autostart"
echo ""

# Step 9: Summary
echo "=========================================="
echo "SETUP COMPLETE"
echo "=========================================="
echo ""
echo "✓ Display managers disabled"
echo "✓ Console boot configured"
echo "✓ Dependencies installed (unclutter, xinit)"
echo "✓ Systemd service created and enabled"
echo "✓ User permissions configured"
echo "✓ Cursor hiding configured"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Ensure these files are in /home/pi/:"
echo "   - 010_xephyr.sh"
echo "   - lib/logging.sh"
echo "   - lib/touchscreen-setup.sh"
echo "   - kiosk-autofill-extension/"
echo ""
echo "2. Reboot the system:"
echo "   sudo reboot"
echo ""
echo "3. After reboot:"
echo "   - Kiosk should start automatically"
echo "   - Cursors should be hidden"
echo "   - Touch input should work"
echo ""
echo "To check status after reboot:"
echo "  sudo systemctl status kiosk.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u kiosk.service -f"
echo ""
echo "To restart kiosk:"
echo "  sudo systemctl restart kiosk.service"
echo ""
echo "=========================================="
