#!/usr/bin/env bash
ID="$1"
FILE="$HOME/.config/eww/shortcuts.json"
[ ! -f "$FILE" ] && exit

python3 - <<PYEOF
import json
with open('$FILE') as f:
    data = json.load(f)
data = [x for x in data if x['id'] != '$ID']
with open('$FILE', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF


eww update SHORTCUTS="$(bash ~/.config/eww/shortcuts-list.sh)"
