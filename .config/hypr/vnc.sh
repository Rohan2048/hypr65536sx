#VNC SERVER(INSTALL IF HAVEN'T DONE YET):
#sudo dnf install wayvnc
#Normally,
#killall wayvnc 2>/dev/null
#wayvnc --render-cursor 0.0.0.0 5900 &

#!/bin/bash
if pgrep -x wayvnc > /dev/null; then
    killall wayvnc
    notify-send "VNC" "Server stopped"
else
    wayvnc --render-cursor 0.0.0.0 5900 &
    notify-send "VNC" "Server started - $(hostname -I | awk '{print $1}'):5900"
fi
