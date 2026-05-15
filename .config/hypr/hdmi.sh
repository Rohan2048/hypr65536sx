#!/usr/bin/env bash

# -----------------------------------------------
# HDMI OUTPUT SCRIPT
# Run: bash ~/.config/hypr/hdmi.sh
# -----------------------------------------------

INTERNAL="eDP-1"
EXTERNAL=$(hyprctl monitors all | grep -o "HDMI-A-[0-9]*" | head -n1)
if [ -z "$EXTERNAL" ]; then
    EXTERNAL="HDMI-A-1"
fi

# Auto-detect resolutions and refresh rates
INTERNAL_RES=$(hyprctl monitors all | awk "/Monitor $INTERNAL/{found=1} found && /availableModes/{print \$2; exit}" | cut -d@ -f1)
INTERNAL_REFRESH=$(hyprctl monitors all | awk "/Monitor $INTERNAL/{found=1} found && /availableModes/{print \$2; exit}" | cut -d@ -f2 | cut -dH -f1)
EXTERNAL_RES=$(hyprctl monitors all | awk "/Monitor $EXTERNAL/{found=1} found && /availableModes/{print \$2; exit}" | cut -d@ -f1)
EXTERNAL_REFRESH=$(hyprctl monitors all | awk "/Monitor $EXTERNAL/{found=1} found && /availableModes/{print \$2; exit}" | cut -d@ -f2 | cut -dH -f1)

# Background monitor event watcher (only start if not already running)
if ! pgrep -f "socket2.sock" > /dev/null; then
    socat - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
        if echo "$line" | grep -q "monitoradded"; then
            notify-send "Display" "Monitor connected - press Alt+S to configure"
        elif echo "$line" | grep -q "monitorremoved"; then
            hyprctl keyword monitor "$INTERNAL,$INTERNAL_RES@$INTERNAL_REFRESH,0x0,1.5"
            killall -9 eww 2>/dev/null && eww daemon
            sleep 1
            eww open bar-window && eww open notch-window
            killall -9 dunst 2>/dev/null && dunst &
            notify-send "Display" "Monitor disconnected - reverted to laptop screen"
        fi
    done &
fi

# Check which monitors are connected
INTERNAL_CONNECTED=$(hyprctl monitors all | grep -c "^Monitor $INTERNAL")
EXTERNAL_CONNECTED=$(hyprctl monitors all | grep -c "^Monitor $EXTERNAL")

if [ "$INTERNAL_CONNECTED" -eq 0 ] && [ "$EXTERNAL_CONNECTED" -eq 0 ]; then
    notify-send "Display" "No display detected"
    exit 0
fi

# Build options based on what's connected
OPTIONS="Laptop Only"
if [ "$EXTERNAL_CONNECTED" -gt 0 ]; then
    OPTIONS="$OPTIONS\nExternal Only\nMirror\nExtend"
fi

# Count lines for adaptive height
LINE_COUNT=$(echo -e "$OPTIONS" | wc -l)
WINDOW_HEIGHT=$(( LINE_COUNT * 50 + 20 ))

CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -p "Display Mode" \
    -theme-str 'inputbar { enabled: false; }' \
    -theme-str 'mainbox { children: [ listview ]; }' \
    -theme-str 'element { horizontal-align: 0.5; padding: 8px 0px; }' \
    -theme-str 'element-text { horizontal-align: 0.5; margin: 0px; }' \
    -theme-str "listview { lines: ${LINE_COUNT}; scrollbar: false; padding: 0px; }" \
    -theme-str "window { width: 300px; height: ${WINDOW_HEIGHT}px; }" \
    -no-custom)

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    "Laptop Only")
        hyprctl keyword monitor "$INTERNAL,$INTERNAL_RES@$INTERNAL_REFRESH,0x0,1.5"
        hyprctl keyword monitor "$EXTERNAL,disable" 2>/dev/null
        ;;
    "External Only")
        hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RES@$EXTERNAL_REFRESH,0x0,1.5"
        hyprctl keyword monitor "$INTERNAL,disable"
        ;;
    "Mirror")
        hyprctl keyword monitor "$INTERNAL,$INTERNAL_RES@$INTERNAL_REFRESH,0x0,1.5"
        hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RES@$EXTERNAL_REFRESH,0x0,1,mirror,$INTERNAL"
        ;;
    "Extend")
        hyprctl keyword monitor "$INTERNAL,$INTERNAL_RES@$INTERNAL_REFRESH,0x0,1.5"
        hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RES@$EXTERNAL_REFRESH,1280x0,1.5"
        ;;
esac

killall -9 eww 2>/dev/null && eww daemon
sleep 1
eww open bar-window & eww open top-bar-window
killall -9 dunst 2>/dev/null && dunst &
notify-send "Display" "Applied: $CHOICE"
