#!/usr/bin/env bash
# music-seek.sh
# Called by the eww scale's :onchange with a value 0–100 (percentage).
# Converts that to seconds using the track's actual duration, then seeks.

PERCENT="$1"

if [[ -z "$PERCENT" ]]; then
    exit 1
fi

# Get duration in microseconds from mpris, convert to seconds
LENGTH_US=$(playerctl metadata mpris:length 2>/dev/null)
if [[ -z "$LENGTH_US" || "$LENGTH_US" == "0" ]]; then
    exit 1
fi

# Compute target position in seconds: (percent / 100) * duration_seconds
TARGET=$(awk "BEGIN{printf \"%.3f\", ($PERCENT / 100.0) * ($LENGTH_US / 1000000.0)}")

playerctl position "$TARGET"
