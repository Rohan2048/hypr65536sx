#!/usr/bin/env bash
# Outputs a single <box> with buttons for each icon/command

ICON_MAP="/tmp/eww/icon-map.txt"
[ ! -f "$ICON_MAP" ] && exit 0

echo "<box orientation='h' spacing='4'>"
while IFS="::" read -r icon cmd; do
  [ -z "$icon" ] || [ -z "$cmd" ] && continue
  echo "<button onclick='$cmd'><image path='$icon' width='24' height='24'/></button>"
done < "$ICON_MAP"
echo "</box>"
