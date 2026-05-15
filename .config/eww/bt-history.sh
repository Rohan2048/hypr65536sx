#!/bin/bash
# bt-history.sh — names only storage, MAC resolved dynamically

HIST="$HOME/.config/eww/bt-history.json"
mkdir -p "$(dirname "$HIST")"

if [ ! -f "$HIST" ] || ! python3 -c "import json; json.load(open('$HIST'))" 2>/dev/null; then
    echo '[]' > "$HIST"
fi

normalize() {
    echo "$1" | sed 's/ *$//'
}

update_device() {
    NAME="$1"
    [ -z "$NAME" ] && return
    NAME=$(normalize "$NAME")
    python3 - "$HIST" "$NAME" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list) and data and isinstance(data[0], dict):
        data = [x.get("name", "") for x in data if x.get("name")]
except:
    data = []
if name in data:
    data.remove(name)
data.insert(0, name)
data = data[:10]
with open(path, 'w') as f:
    json.dump(data, f)
PY
}

list_devices() {
    python3 - "$HIST" << 'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    if isinstance(data, list) and data and isinstance(data[0], dict):
        data = [x.get("name", "") for x in data if x.get("name")]
except:
    data = []
print(json.dumps([{"name": x} for x in data]))
PY
}

get_mac_from_name() {
    bluetoothctl devices | grep -F "$1" | awk '{print $2; exit}'
}

connect_device() {
    MAC=$(get_mac_from_name "$1")
    [ -n "$MAC" ] && bluetoothctl connect "$MAC" &>/dev/null &
}

disconnect_device() {
    MAC=$(get_mac_from_name "$1")
    [ -n "$MAC" ] && bluetoothctl disconnect "$MAC" &>/dev/null &
}

forget_device() {
    MAC=$(get_mac_from_name "$1")
    [ -n "$MAC" ] && bluetoothctl remove "$MAC" &>/dev/null &
}

case "$1" in
    list)       list_devices;           exit ;;
    update)     update_device "$2";     exit ;;
    connect)    connect_device "$2";    exit ;;
    disconnect) disconnect_device "$2"; exit ;;
    forget)     forget_device "$2";     exit ;;
esac

# --------------------------
# MONITOR — D-Bus subscriber
# Emits {"device":"...","history":[...]} to stdout on startup and on every
# connection change. deflisten binds directly to this stdout stream —
# no cache file, no polling, no while loop.
# Requires: python3-dbus (python3-dbus package)
# --------------------------

python3 - "$HIST" << 'PY'
import sys, json, dbus, dbus.mainloop.glib
from gi.repository import GLib

HIST = sys.argv[1]

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()

def get_connected_name():
    try:
        mgr = dbus.Interface(
            bus.get_object('org.bluez', '/'),
            'org.freedesktop.DBus.ObjectManager'
        )
        for path, ifaces in mgr.GetManagedObjects().items():
            dev = ifaces.get('org.bluez.Device1', {})
            if dev.get('Connected') and dev.get('Name'):
                return str(dev['Name']).rstrip()
    except Exception:
        pass
    # Bluetooth off or no device connected
    try:
        import subprocess
        out = subprocess.check_output(
            ['rfkill', 'list', 'bluetooth'], text=True
        )
        if 'Soft blocked: no' in out:
            return 'Bluetooth-ON'
    except Exception:
        pass
    return 'Bluetooth-OFF'

def load_history():
    try:
        with open(HIST) as f:
            data = json.load(f)
        if data and isinstance(data[0], dict):
            data = [x.get('name', '') for x in data if x.get('name')]
        return [{"name": x} for x in data]
    except Exception:
        return []

def update_history(name):
    if not name or name in ('Bluetooth-OFF', 'Bluetooth-ON'):
        return
    try:
        with open(HIST) as f:
            data = json.load(f)
        if data and isinstance(data[0], dict):
            data = [x.get('name', '') for x in data if x.get('name')]
    except Exception:
        data = []
    if name in data:
        data.remove(name)
    data.insert(0, name)
    data = data[:10]
    with open(HIST, 'w') as f:
        json.dump(data, f)

def emit(device):
    print(json.dumps({"device": device, "history": load_history()}), flush=True)

def on_properties_changed(interface, changed, invalidated, path=None):
    # Adapter1.Powered — radio toggled on or off
    if interface == 'org.bluez.Adapter1' and 'Powered' in changed:
        if changed['Powered']:
            name = get_connected_name()  # ON but nothing connected yet
            emit(name)
        else:
            emit('Bluetooth-OFF')
        return
    # Device1.Connected — device connected or disconnected
    if interface == 'org.bluez.Device1' and 'Connected' in changed:
        name = get_connected_name()
        update_history(name)
        emit(name)

# Emit current state immediately — deflisten gets a live value on startup
current = get_connected_name()
update_history(current)
emit(current)

# Subscribe once — GLib dispatches callbacks, no loop
bus.add_signal_receiver(
    on_properties_changed,
    signal_name='PropertiesChanged',
    dbus_interface='org.freedesktop.DBus.Properties',
    bus_name=None,
    path_keyword='path'
)

GLib.MainLoop().run()   # event-driven, no polling
PY
