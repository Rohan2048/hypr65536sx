#!/usr/bin/env bash
# notif-listener.sh — emits NOTIF_LIST JSON
# driven by dunst dbus signal
# Debounced: rapid signals collapse into one emit after 300ms settle

emit() {
    bash ~/.config/eww/notif-history.sh
}

emit

LAST_EMIT=0

dbus-monitor --session "type='signal',interface='org.freedesktop.Notifications'" 2>/dev/null |
grep --line-buffered -E "member=(Notify|NotificationClosed|CloseNotification)" |
while read -r _; do
    NOW=$(date +%s%3N)
    if (( NOW - LAST_EMIT > 300 )); then
        LAST_EMIT=$NOW
        emit
    fi
done
