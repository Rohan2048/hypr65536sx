#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('GdkPixbuf', '2.0')

from gi.repository import Gtk, Adw, GdkPixbuf, GLib, Gdk, Gio
import subprocess
import json
import os
import threading
import sys

DEFAULTS = {
    "background": "#1a1a2e", "foreground": "#e0e0e0",
    "color0": "#1a1a2e",  "color1": "#7c5cbf",
    "color2": "#5c9e6e",  "color3": "#c4a84f",
    "color4": "#4f7fc4",  "color5": "#9e5c9e",
    "color6": "#5c9e9e",  "color7": "#c0c0c0",
    "color8": "#666699",
}

def load_wal_colors():
    try:
        path = os.path.expanduser("~/.cache/wal/colors.json")
        with open(path) as f:
            data = json.load(f)
        c = {}
        c["background"] = data["special"].get("background", DEFAULTS["background"])
        c["foreground"] = data["special"].get("foreground", DEFAULTS["foreground"])
        for i in range(16):
            k = f"color{i}"
            c[k] = data["colors"].get(k, DEFAULTS.get(k, "#888888"))
        return c
    except Exception:
        return dict(DEFAULTS)

def hex_rgba(h, a=1.0):
    h = h.lstrip("#")
    if len(h) == 8:
        a = int(h[6:8], 16) / 255.0
        h = h[:6]
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return f"rgba({r},{g},{b},{a:.2f})"

def build_css(c):
    bg  = hex_rgba(c["background"], 0.50)
    fg  = c["foreground"]
    c1  = c["color1"]
    c7  = c.get("color7", fg)
    c8  = c.get("color8", "#666666")
    c1a = hex_rgba(c1, 0.25)
    c1b = hex_rgba(c1, 0.55)
    c1c = hex_rgba(c1, 0.70)
    c8a = hex_rgba(c8, 0.35)
    c8b = hex_rgba(c8, 0.20)
    return f"""
window.music-player-win {{ background-color: transparent; }}
.player-root {{
    background-color: {bg};
    border-radius: 20px;
    border: 1.5px solid {c1b};
    padding: 20px 18px 16px 18px;
}}
.title-label {{ font-family: "LED Counter 7", monospace; font-size: 15px; font-weight: bold; color: {fg}; }}
.artist-label {{ font-family: "LED Counter 7", monospace; font-size: 12px; color: {c7}; }}
.album-label {{ font-family: "LED Counter 7", monospace; font-size: 10px; color: {c8}; }}
.time-label {{ font-family: "LED Counter 7", monospace; font-size: 10px; color: {c8}; }}
.ctrl-btn {{ background-color: transparent; border: none; border-radius: 50%; padding: 6px; min-width: 38px; min-height: 38px; }}
.ctrl-btn:hover {{ background-color: {c1a}; }}
.ctrl-btn:active {{ background-color: {c1b}; }}
.play-btn {{ background-color: {c1a}; border: 1.5px solid {c1c}; border-radius: 50%; padding: 8px; min-width: 46px; min-height: 46px; }}
.play-btn:hover {{ background-color: {c1b}; }}
.no-art {{ background-color: {c8b}; border-radius: 12px; font-size: 28px; color: {c8}; }}
scale trough {{ background-color: {c8a}; border-radius: 4px; min-height: 4px; }}
scale trough highlight {{ background-color: {c1}; border-radius: 4px; }}
scale slider {{ background-color: {fg}; border-radius: 50%; min-width: 12px; min-height: 12px; border: none; box-shadow: none; }}
"""

def get_initial_from_args():
    result = {
        "status": "Stopped", "title": "", "artist": "",
        "album": "", "art_url": "", "position": 0.0, "duration": 0.0,
    }
    try:
        if len(sys.argv) >= 3:
            result["status"] = sys.argv[1]
            meta = json.loads(sys.argv[2])
            result["title"]   = meta.get("title", "")
            result["artist"]  = meta.get("artist", "")
            result["album"]   = meta.get("album", "")
            result["art_url"] = meta.get("art", "")
            dur = meta.get("duration", 0)
            result["duration"] = float(dur) if dur else 0.0
    except Exception:
        pass
    return result

def get_position():
    try:
        r = subprocess.run(["playerctl", "position"], capture_output=True, text=True, timeout=2)
        return float(r.stdout.strip()) if r.returncode == 0 else 0.0
    except Exception:
        return 0.0

def seek(secs):
    run_cmd_async(["playerctl", "position", str(round(secs, 2))])

def fmt(secs):
    secs = max(0, int(secs))
    return f"{secs//60:02d}:{secs%60:02d}"

def run_cmd(cmd):
    try:
        subprocess.run(cmd, capture_output=True, timeout=2)
    except Exception:
        pass

def run_cmd_async(cmd):
    threading.Thread(target=lambda: run_cmd(cmd), daemon=True).start()


class MusicPlayer(Gtk.ApplicationWindow):
    def __init__(self, app, colors, initial):
        super().__init__(application=app)
        self.colors       = colors
        self._seeking     = False
        self._current_art = ""
        self._art_cache   = {}
        self._duration    = 0.0
        self._status      = initial["status"]

        self.set_title("Music Player")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(340, -1)
        self.add_css_class("music-player-win")

        prov = Gtk.CssProvider()
        prov.load_from_string(build_css(colors))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.connect("notify::is-active", self._on_focus)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        root.add_css_class("player-root")
        self.set_child(root)

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        root.append(top)

        self.art_stack = Gtk.Stack()
        self.art_stack.set_size_request(84, 84)
        self.art_img = Gtk.Picture()
        self.art_img.set_size_request(84, 84)
        self.art_img.set_content_fit(Gtk.ContentFit.COVER)
        self.no_art = Gtk.Label(label="♪")
        self.no_art.add_css_class("no-art")
        self.no_art.set_size_request(84, 84)
        self.no_art.set_halign(Gtk.Align.CENTER)
        self.no_art.set_valign(Gtk.Align.CENTER)
        self.art_stack.add_named(self.art_img, "art")
        self.art_stack.add_named(self.no_art,  "noart")
        self.art_stack.set_visible_child_name("noart")
        top.append(self.art_stack)

        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        info.set_valign(Gtk.Align.CENTER)
        info.set_hexpand(True)
        top.append(info)

        self.lbl_title  = self._label("Not Playing", "title-label",  24)
        self.lbl_artist = self._label("",            "artist-label", 24)
        self.lbl_album  = self._label("",            "album-label",  24)
        info.append(self.lbl_title)
        info.append(self.lbl_artist)
        info.append(self.lbl_album)

        seek_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        root.append(seek_box)
        self.seek = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 0.5)
        self.seek.set_draw_value(False)
        self.seek.set_hexpand(True)
        drag = Gtk.GestureDrag()
        drag.connect("drag-begin", lambda *_: setattr(self, "_seeking", True))
        drag.connect("drag-end",   self._on_drag_end)
        self.seek.add_controller(drag)
        seek_box.append(self.seek)

        times = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.lbl_pos = Gtk.Label(label="00:00")
        self.lbl_pos.add_css_class("time-label")
        self.lbl_pos.set_hexpand(True)
        self.lbl_pos.set_halign(Gtk.Align.START)
        self.lbl_dur = Gtk.Label(label="00:00")
        self.lbl_dur.add_css_class("time-label")
        self.lbl_dur.set_halign(Gtk.Align.END)
        times.append(self.lbl_pos)
        times.append(self.lbl_dur)
        seek_box.append(times)

        ctrl = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        ctrl.set_halign(Gtk.Align.CENTER)
        root.append(ctrl)

        self.btn_prev = self._icon_btn("~/.config/icons/previous.png", "media-skip-backward", "ctrl-btn",
                                       lambda *_: run_cmd_async(["playerctl", "previous"]))
        self.btn_play = self._icon_btn("~/.config/icons/play.png",     "media-playback-start","play-btn",
                                       self._toggle_play)
        self.btn_next = self._icon_btn("~/.config/icons/next.png",     "media-skip-forward",  "ctrl-btn",
                                       lambda *_: run_cmd_async(["playerctl", "next"]))
        ctrl.append(self.btn_prev)
        ctrl.append(self.btn_play)
        ctrl.append(self.btn_next)

        self._apply_metadata(initial)
        GLib.timeout_add(1000, self._tick)

    def _label(self, text, css, maxchars):
        l = Gtk.Label(label=text)
        l.add_css_class(css)
        l.set_halign(Gtk.Align.START)
        l.set_ellipsize(3)
        l.set_max_width_chars(maxchars)
        return l

    def _icon_btn(self, png, icon_fallback, css_class, callback):
        btn = Gtk.Button()
        btn.add_css_class(css_class)
        self._set_icon(btn, png, icon_fallback)
        btn.connect("clicked", callback)
        return btn

    def _set_icon(self, btn, png_path, fallback):
        path = os.path.expanduser(png_path)
        if os.path.exists(path):
            img = Gtk.Image.new_from_file(path)
            img.set_pixel_size(20)
            btn.set_child(img)
        else:
            btn.set_child(Gtk.Image.new_from_icon_name(fallback))

    def _on_focus(self, *_):
        if not self.is_active():
            GLib.timeout_add(120, self.close)

    def _on_drag_end(self, gesture, ox, oy):
        val = self.seek.get_value()
        if self._duration > 0:
            seek(val / 100.0 * self._duration)
        self._seeking = False

    def _toggle_play(self, *_):
        run_cmd_async(["playerctl", "play-pause"])
        if self._status == "Playing":
            self._status = "Paused"
            self._set_icon(self.btn_play, "~/.config/icons/play.png",  "media-playback-start")
        else:
            self._status = "Playing"
            self._set_icon(self.btn_play, "~/.config/icons/pause.png", "media-playback-pause")

    def _load_art(self, path):
        if path in self._art_cache:
            self._show_art(self._art_cache[path])
            return
        def _bg():
            try:
                if not os.path.exists(path):
                    GLib.idle_add(self.art_stack.set_visible_child_name, "noart")
                    return
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 84, 84, False)
                tex = Gdk.Texture.new_for_pixbuf(pb)
                if len(self._art_cache) >= 20:
                    self._art_cache.pop(next(iter(self._art_cache)))
                self._art_cache[path] = tex
                GLib.idle_add(self._show_art, tex)
            except Exception:
                GLib.idle_add(self.art_stack.set_visible_child_name, "noart")
        threading.Thread(target=_bg, daemon=True).start()

    def _show_art(self, tex):
        self.art_img.set_paintable(tex)
        self.art_stack.set_visible_child_name("art")

    def _apply_metadata(self, meta):
        status  = meta["status"]
        title   = meta["title"]
        artist  = meta["artist"]
        album   = meta["album"]
        dur     = meta["duration"]
        pos     = meta.get("position", 0.0)
        art_url = meta["art_url"]

        self._status   = status
        self._duration = dur
        self.lbl_title.set_text(title   or "Not Playing")
        self.lbl_artist.set_text(artist or "")
        self.lbl_album.set_text(album   or "")

        if dur > 0 and not self._seeking:
            self.seek.set_value((pos / dur) * 100.0)
            self.lbl_pos.set_text(fmt(pos))
            self.lbl_dur.set_text(fmt(dur))
        else:
            self.seek.set_value(0)
            self.lbl_pos.set_text("00:00")
            self.lbl_dur.set_text("00:00")

        if status == "Playing":
            self._set_icon(self.btn_play, "~/.config/icons/pause.png",  "media-playback-pause")
        else:
            self._set_icon(self.btn_play, "~/.config/icons/play.png",   "media-playback-start")

        if art_url != self._current_art:
            self._current_art = art_url
            if art_url and not art_url.startswith("/tmp/.org.chromium") and not art_url.startswith("/tmp/.org.brave"):
                self._load_art(art_url)
            else:
                self.art_stack.set_visible_child_name("noart")

    def _tick(self):
        if self._duration == 0.0:
            return True
        def _bg():
            pos = get_position()
            GLib.idle_add(self._update_position, pos)
        threading.Thread(target=_bg, daemon=True).start()
        return True

    def _update_position(self, pos):
        if self._duration > 0 and not self._seeking:
            self.seek.set_value((pos / self._duration) * 100.0)
            self.lbl_pos.set_text(fmt(pos))


class PlayerApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="com.eww.MusicPlayer",
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        self.connect("activate", self._on_activate)

    def _on_activate(self, app):
        colors  = load_wal_colors()
        initial = get_initial_from_args()
        win = MusicPlayer(app, colors, initial)
        win.present()

if __name__ == "__main__":
    PlayerApp().run(sys.argv)
