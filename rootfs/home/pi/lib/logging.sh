#!/usr/bin/env bash
################################################################################
# Logging Library for Kiosk System
# Provides simple logging functions for touchscreen and system components
################################################################################

# Default log configuration (can be overridden by sourcing script)
: "${TOUCHSCREEN_LOG_LEVEL:=2}"  # 0=none, 1=errors, 2=info, 3=debug
: "${TOUCHSCREEN_LOG:=/var/log/kiosk/touchscreen.log}"

# Ensure log directory exists
_ensure_log_directory() {
    local log_dir=$(dirname "$TOUCHSCREEN_LOG")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            # Fall back to /tmp if can't create in /var/log
            TOUCHSCREEN_LOG="/tmp/kiosk-touchscreen.log"
        }
    fi
}

# Initialize logging (call once at start)
init_logging() {
    _ensure_log_directory

    # Write startup marker
    if [ "$TOUCHSCREEN_LOG_LEVEL" -gt 0 ]; then
        echo "========================================" >> "$TOUCHSCREEN_LOG"
        echo "Kiosk startup: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TOUCHSCREEN_LOG"
        echo "========================================" >> "$TOUCHSCREEN_LOG"
    fi
}

# Internal logging function
_log() {
    local level=$1
    local level_name=$2
    shift 2
    local message="$*"

    if [ "$TOUCHSCREEN_LOG_LEVEL" -ge "$level" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level_name] $message" >> "$TOUCHSCREEN_LOG"
    fi

    # Also output to stderr for errors
    if [ "$level" -eq 1 ]; then
        echo "ERROR: $message" >&2
    fi
}

# Public logging functions
log_error() {
    _log 1 "ERROR" "$@"
}

log_info() {
    _log 2 "INFO" "$@"
}

log_debug() {
    _log 3 "DEBUG" "$@"
}

# Log command execution and result
log_cmd() {
    local cmd="$*"
    log_debug "Executing: $cmd"

    if eval "$cmd" 2>&1 | tee -a "$TOUCHSCREEN_LOG" >/dev/null; then
        log_debug "Command succeeded: $cmd"
        return 0
    else
        log_error "Command failed: $cmd"
        return 1
    fi
}
