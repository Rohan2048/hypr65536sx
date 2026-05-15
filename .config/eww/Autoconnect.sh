#!/bin/bash
# Autoconnect WiFi and Bluetooth at eww startup if enabled but idle.

# --- WiFi ---
WIFI_STATE=$(nmcli -t -f WIFI g | tr -d '[:space:]')
if [ "$WIFI_STATE" = "enabled" ]; then
  CONNECTED=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}')
  if [ -z "$CONNECTED" ]; then
    IFACE=$(nmcli -t -f DEVICE,TYPE device | awk -F: '/wireless/{print $1; exit}')
    [ -n "$IFACE" ] && nmcli device connect "$IFACE" 2>/dev/null
  fi
fi

# --- Bluetooth ---
if rfkill list bluetooth | grep -q 'Soft blocked: no'; then
  # Power on controller
  bluetoothctl power on 2>/dev/null

  # Try each paired device until one connects
  bluetoothctl paired-devices 2>/dev/null | awk '{print $2}' | while read MAC; do
    [ -z "$MAC" ] && continue
    # Skip if already connected
    bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Connected: yes' && continue
    bluetoothctl connect "$MAC" 2>/dev/null
    sleep 2
    # Stop trying once one connects
    bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Connected: yes' && break
  done
fi
