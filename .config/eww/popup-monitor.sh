#!/usr/bin/env bash

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr/ | head -1)

POPUPS="notifications-popup wifi-popup bt-popup battery-popup shortcuts-window commands-window brightness-popup volume-popup music-popup calendar-popup"

socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | \
grep --line-buffered "^activewindow>>" | \
while read -r line; do
    # Skip the expensive eww active-windows call if no popup is flagged open
    [ ! -f /tmp/eww/popup_open ] && continue

    ACTIVE_WINDOWS=$(eww active-windows 2>/dev/null)
    if echo "$ACTIVE_WINDOWS" | grep -qE "wifi-popup|bt-popup|battery-popup|notifications-popup|shortcuts-window|commands-window|brightness-popup|volume-popup|music-popup|calendar-popup"; then
        for P in $POPUPS; do
            eww close "$P" 2>/dev/null
        done
        rm -f /tmp/eww/popup_open
    fi
done
