#!/usr/bin/env bash
################################################################################
# Helper script to run diagnostics from within X session
# This ensures proper X display access
################################################################################

# Set display
export DISPLAY=:0

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run diagnostic
"$SCRIPT_DIR/diagnose-touchscreens.sh" "$@"
