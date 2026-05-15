#!/usr/bin/env python3
"""
Unified MPRIS daemon for eww deflisten.
Emits KEY=value lines to stdout:
  PLAYER_STATUS=Playing
  PLAYER_TITLE=Some Song
  PLAYER_META={"title":"...","artist":"...",...}
"""
import asyncio, json, sys, time
from dbus_next.aio import MessageBus
from dbus_next.message import Message
from dbus_next import MessageType

fmt  = lambda s: f"{int(max(0,s))//60:02d}:{int(max(0,s))%60:02d}"
us   = lambda v: (v or 0) / 1_000_000.0
sval = lambda m, k: (m[k].value if k in m else "") or ""

EMPTY_META   = '{"title":"","artist":"","album":"","art":"","duration":0,"duration_fmt":"00:00"}'
EMPTY_STATUS = "Stopped"
EMPTY_TITLE  = ""

def emit(key, value):
    sys.stdout.write(f"{key}={value}\n")
    sys.stdout.flush()

def emit_empty():
    emit("PLAYER_STATUS", EMPTY_STATUS)
    emit("PLAYER_TITLE",  EMPTY_TITLE)
    emit("PLAYER_META",   EMPTY_META)

def build_meta(m):
    av = m.get("xesam:artist")
    artist = (", ".join(av.value) if isinstance(av.value, list) else av.value) if av else ""
    art = sval(m, "mpris:artUrl").replace("file://", "")
    dur = us(m["mpris:length"].value) if "mpris:length" in m else 0.0
    return {
        "title":        sval(m, "xesam:title"),
        "artist":       artist,
        "album":        sval(m, "xesam:album"),
        "art":          art,
        "duration":     int(dur),
        "duration_fmt": fmt(dur),
    }

async def main():
    emit_empty()

    bus = await MessageBus().connect()
    ps             = {}   # name → PlaybackStatus
    unique_to_name = {}   # unique bus name → well-known name

    def active():
        for n, s in ps.items():
            if s == "Playing": return n
        return next(iter(ps), None)

    async def dbus_get(dest, prop):
        reply = await bus.call(Message(
            destination=dest,
            path="/org/mpris/MediaPlayer2",
            interface="org.freedesktop.DBus.Properties",
            member="Get", signature="ss",
            body=["org.mpris.MediaPlayer2.Player", prop],
        ))
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError(reply.body[0])
        return reply.body[0]

    async def push(name):
        a = active()
        if not a:
            emit_empty(); return
        if name != a: return
        try:
            sv = await dbus_get(a, "PlaybackStatus")
            mv = await dbus_get(a, "Metadata")
            ps[a] = sv.value
            m = build_meta(mv.value)
            emit("PLAYER_STATUS", sv.value)
            emit("PLAYER_TITLE",  m["title"])
            emit("PLAYER_META",   json.dumps(m))
        except Exception:
            emit_empty()

    def on_signal(msg):
        if (msg.path      != "/org/mpris/MediaPlayer2"         or
            msg.interface != "org.freedesktop.DBus.Properties" or
            msg.member    != "PropertiesChanged"):
            return
        name = unique_to_name.get(msg.sender)
        if not name: return
        changed = msg.body[1] if len(msg.body) > 1 else {}
        if "PlaybackStatus" in changed:
            ps[name] = changed["PlaybackStatus"].value
        if "Metadata" in changed or "PlaybackStatus" in changed:
            asyncio.ensure_future(push(name))

    bus.add_message_handler(on_signal)

    bus.add_message_handler(lambda msg: (
        msg.interface == "org.freedesktop.DBus" and
        msg.member    == "NameOwnerChanged" and
        msg.body and msg.body[0].startswith("org.mpris.MediaPlayer2.") and
        asyncio.ensure_future(
            add(msg.body[0]) if msg.body[2] else remove(msg.body[0])
        )
    ) or None)

    async def get_unique(name):
        reply = await bus.call(Message(
            destination="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
            interface="org.freedesktop.DBus",
            member="GetNameOwner", signature="s", body=[name],
        ))
        return reply.body[0]

    async def add(name, retries=6):
        for attempt in range(retries):
            try:
                sv = await dbus_get(name, "PlaybackStatus")
                ps[name] = sv.value
                try:
                    unique_to_name[await get_unique(name)] = name
                except Exception:
                    pass
                a = active()
                if a: await push(a)
                return
            except Exception:
                if attempt < retries - 1:
                    await asyncio.sleep(0.25 * (attempt + 1))

    async def remove(name):
        ps.pop(name, None)
        for u, n in list(unique_to_name.items()):
            if n == name: unique_to_name.pop(u, None)
        a = active()
        if a: await push(a)
        else: emit_empty()

    reply = await bus.call(Message(
        destination="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus",
        member="ListNames",
    ))
    for n in (reply.body[0] or []):
        if n.startswith("org.mpris.MediaPlayer2."):
            await add(n)

    await asyncio.get_event_loop().create_future()

asyncio.run(main())
