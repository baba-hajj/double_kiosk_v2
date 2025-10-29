#!/bin/bash
# Performance Monitoring Script for Dual-Kiosk System
# Run this before and after optimization to compare results

OUTPUT_FILE="/tmp/kiosk-performance-$(date +%Y%m%d-%H%M%S).txt"

echo "=========================================="
echo "KIOSK SYSTEM PERFORMANCE REPORT"
echo "=========================================="
echo "Date: $(date)" | tee "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# System Information
echo "1. SYSTEM INFORMATION:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
echo "CPU: $(cat /proc/cpuinfo | grep 'Model' | head -1 | cut -d: -f2 | xargs)" | tee -a "$OUTPUT_FILE"
echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')" | tee -a "$OUTPUT_FILE"
echo "GPU Memory: $(vcgencmd get_mem gpu | cut -d= -f2)" | tee -a "$OUTPUT_FILE"
echo "CPU Temp: $(vcgencmd measure_temp | cut -d= -f2)" | tee -a "$OUTPUT_FILE"
echo "CPU Freq: $(vcgencmd measure_clock arm | cut -d= -f2 | awk '{print $1/1000000 " MHz"}')" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Memory Usage
echo "2. MEMORY USAGE:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
free -h | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Memory by Chromium processes:" | tee -a "$OUTPUT_FILE"
ps aux | grep chromium | grep -v grep | awk '{print $2, $4, $6, $11}' | head -10 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

TOTAL_CHROMIUM_MEM=$(ps aux | grep chromium | grep -v grep | awk '{sum+=$6} END {print sum/1024 " MB"}')
echo "Total Chromium Memory: $TOTAL_CHROMIUM_MEM" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# CPU Usage
echo "3. CPU USAGE:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
top -b -n 1 | head -15 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "CPU usage by Chromium:" | tee -a "$OUTPUT_FILE"
ps aux | grep chromium | grep -v grep | awk '{print $3, $11}' | head -10 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# GPU Status
echo "4. GPU STATUS:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
echo "GPU Memory Split: $(vcgencmd get_mem gpu)" | tee -a "$OUTPUT_FILE"
echo "GPU Memory Used: $(vcgencmd get_mem reloc)" | tee -a "$OUTPUT_FILE"
if command -v glxinfo &> /dev/null; then
    echo "OpenGL Renderer: $(DISPLAY=:0 glxinfo | grep "OpenGL renderer" | cut -d: -f2 | xargs)" | tee -a "$OUTPUT_FILE"
    echo "OpenGL Version: $(DISPLAY=:0 glxinfo | grep "OpenGL version" | cut -d: -f2 | xargs)" | tee -a "$OUTPUT_FILE"
fi
echo "" | tee -a "$OUTPUT_FILE"

# Display Configuration
echo "5. DISPLAY CONFIGURATION:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
DISPLAY=:0 xrandr | grep " connected" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Chromium Process Count
echo "6. CHROMIUM PROCESSES:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
CHROMIUM_COUNT=$(ps aux | grep chromium | grep -v grep | wc -l)
echo "Total Chromium processes: $CHROMIUM_COUNT" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Network Performance (if URL configured)
if [ -n "$URL" ]; then
    echo "7. NETWORK PERFORMANCE:" | tee -a "$OUTPUT_FILE"
    echo "-------------------" | tee -a "$OUTPUT_FILE"
    echo "Testing page load time for: $URL" | tee -a "$OUTPUT_FILE"

    # Test page load 3 times and average
    TOTAL_TIME=0
    for i in {1..3}; do
        TIME=$(curl -s -o /dev/null -w "%{time_total}\n" "$URL" 2>/dev/null || echo "0")
        TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
        echo "  Attempt $i: ${TIME}s" | tee -a "$OUTPUT_FILE"
    done
    AVG_TIME=$(echo "scale=2; $TOTAL_TIME / 3" | bc)
    echo "  Average: ${AVG_TIME}s" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
fi

# Touch Input Latency (estimate based on xinput)
echo "8. INPUT DEVICE STATUS:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
DISPLAY=:0 xinput list | grep -E "pointer|keyboard" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Disk I/O
echo "9. DISK I/O:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
iostat -x 1 2 | tail -n +4 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Cache Status
echo "10. BROWSER CACHE:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
if [ -d "/home/pi/.config/chrome-profile-1" ]; then
    CACHE_SIZE=$(du -sh /home/pi/.config/chrome-profile-1 2>/dev/null | cut -f1)
    echo "Profile 1 cache: $CACHE_SIZE" | tee -a "$OUTPUT_FILE"
fi
if [ -d "/home/pi/.config/chrome-profile-2" ]; then
    CACHE_SIZE=$(du -sh /home/pi/.config/chrome-profile-2 2>/dev/null | cut -f1)
    echo "Profile 2 cache: $CACHE_SIZE" | tee -a "$OUTPUT_FILE"
fi
echo "" | tee -a "$OUTPUT_FILE"

# System Load
echo "11. SYSTEM LOAD:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
uptime | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Chromium Flags (if accessible)
echo "12. CHROMIUM FLAGS:" | tee -a "$OUTPUT_FILE"
echo "-------------------" | tee -a "$OUTPUT_FILE"
ps aux | grep chromium | grep -v grep | head -1 | tr ' ' '\n' | grep "^--" | head -20 | tee -a "$OUTPUT_FILE"
echo "  (showing first 20 flags)" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Performance Summary
echo "=========================================="  | tee -a "$OUTPUT_FILE"
echo "PERFORMANCE SUMMARY" | tee -a "$OUTPUT_FILE"
echo "==========================================" | tee -a "$OUTPUT_FILE"
echo "Total Memory: $(free -h | awk '/^Mem:/ {print $2}')" | tee -a "$OUTPUT_FILE"
echo "Used Memory: $(free -h | awk '/^Mem:/ {print $3}')" | tee -a "$OUTPUT_FILE"
echo "Free Memory: $(free -h | awk '/^Mem:/ {print $4}')" | tee -a "$OUTPUT_FILE"
echo "Chromium Memory: $TOTAL_CHROMIUM_MEM" | tee -a "$OUTPUT_FILE"
echo "Chromium Processes: $CHROMIUM_COUNT" | tee -a "$OUTPUT_FILE"
echo "CPU Temperature: $(vcgencmd measure_temp | cut -d= -f2)" | tee -a "$OUTPUT_FILE"
echo "System Load: $(uptime | awk -F'load average:' '{print $2}' | xargs)" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "=========================================="  | tee -a "$OUTPUT_FILE"
echo "Report saved to: $OUTPUT_FILE"
echo "=========================================="

# Optional: Compare with previous report
LATEST_REPORT=$(ls -t /tmp/kiosk-performance-*.txt 2>/dev/null | sed -n '2p')
if [ -f "$LATEST_REPORT" ]; then
    echo ""
    echo "Previous report available: $LATEST_REPORT"
    echo "To compare, run: diff $LATEST_REPORT $OUTPUT_FILE"
fi
