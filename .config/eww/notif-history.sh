#!/bin/bash
dunstctl history 2>/dev/null | python3 -c "
import json, sys, os, hashlib
try:
    data = json.load(sys.stdin)
    entries = data.get('data', [[]])[0][:20]
    result = []
    os.makedirs('/tmp/eww-notifs', exist_ok=True)
    for e in entries:
        summary = e.get('summary', {}).get('data', 'No title')
        body = e.get('body', {}).get('data', '')
        app = e.get('appname', {}).get('data', '')
        title = f'{app}: {summary}'
        full = f'{app}: {summary}\n{body}' if body else title
        h = hashlib.md5(title.encode()).hexdigest()[:8]
        with open(f'/tmp/eww-notifs/{h}', 'w') as f:
            f.write(full)
        result.append(title)
    if not result:
        result = ['No notifications']
    print(json.dumps(result))
except:
    print(json.dumps(['No notifications']))
"
