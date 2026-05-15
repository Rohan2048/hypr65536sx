#!/usr/bin/env bash
# lazy-toggle.sh
# Toggles vm.dirty_writeback_centisecs in /etc/sysctl.conf.
# Writes new state to /tmp/eww/lazy_mode_state and appends to
# /tmp/eww/lazy_mode_trigger so the deflisten in listeners.yuck picks it up.

SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_KEY="vm.dirty_writeback_centisecs"
DEFAULT_VAL="750"

mkdir -p /tmp/eww
CACHE_STATE="/tmp/eww/lazy_mode_state"
CACHE_KEY_EXISTS="/tmp/eww/lazy_mode_key_exists"
TRIGGER="/tmp/eww/lazy_mode_trigger"

# ── 1. Key-existence check (cold start only) ───────────────────────────────

if [ ! -f "$CACHE_KEY_EXISTS" ]; then
    if grep -qE "^[#[:space:]]*${SYSCTL_KEY}" "$SYSCTL_CONF" 2>/dev/null; then
        echo "1" > "$CACHE_KEY_EXISTS"
    else
        printf '\n# Managed by lazy-toggle.sh\n%s = %s\n' \
            "$SYSCTL_KEY" "$DEFAULT_VAL" \
            | sudo tee -a "$SYSCTL_CONF" > /dev/null
        echo "1" > "$CACHE_KEY_EXISTS"
    fi
fi

# ── 2. Detect current state from file ─────────────────────────────────────

if grep -qE "^[[:space:]]*${SYSCTL_KEY}" "$SYSCTL_CONF" 2>/dev/null; then
    CURRENT_STATE="ON"
else
    CURRENT_STATE="OFF"
fi

# ── 3. Toggle ──────────────────────────────────────────────────────────────

if [ "$CURRENT_STATE" = "ON" ]; then
    sudo sed -i \
        "s|^\([[:space:]]*${SYSCTL_KEY}[[:space:]]*=.*\)|# \1|" \
        "$SYSCTL_CONF"
    sudo sysctl -w "${SYSCTL_KEY}=500" > /dev/null
    NEW_STATE="OFF"
else
    sudo sed -i \
        "s|^[[:space:]]*#[[:space:]]*\(${SYSCTL_KEY}[[:space:]]*=.*\)|\1|" \
        "$SYSCTL_CONF"
    VAL=$(grep -E "^[[:space:]]*${SYSCTL_KEY}" "$SYSCTL_CONF" \
          | tail -n1 | awk -F= '{print $2}' | tr -d '[:space:]')
    [ -n "$VAL" ] && sudo sysctl -w "${SYSCTL_KEY}=${VAL}" > /dev/null
    NEW_STATE="ON"
fi

# ── 4. Update state cache, wake deflisten trigger & print for eww ──────────

echo "$NEW_STATE" > "$CACHE_STATE"
# Append to trigger — tail -f in deflisten picks this up immediately
echo "$NEW_STATE" >> "$TRIGGER"
echo "$NEW_STATE"

sudo sysctl -p > /dev/null
