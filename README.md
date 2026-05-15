# hypr65536
Lightweight configs targeting efficiency

## Structure

```
.config/
├── dunst/          # Notification daemon config (pywal-themed)
├── eww/            # eww bar — bottom bar, top bar, all popups + shortcuts widget
├── fontconfig/     # Font rendering config
├── gtk-3.0/        # GTK3 theme (pywal-driven)
├── gtk-4.0/        # GTK4 theme
├── hypr/           # Hyprland config, hyprlock, scripts
├── icons/          # Custom bar icons (battery, wifi, bluetooth, etc.)
├── rofi/           # Rofi launcher, powermenu, wallpaper selector
├── sounds/         # Battery alert sounds
└── wal/            # Pywal templates and colorschemes
```

## Required Tools

### WM / Display
- `hyprland`
- `hyprlock`
- `swaybg`
- `hyprexpo` plugin — `/usr/lib64/hyprland/libhyprexpo.so`
- `xwayland`

### Bar
- `eww`

### Notifications
- `dunst` / `dunstctl`

### App Launcher
- `rofi` (Wayland build)

### Audio
- `pipewire` + `wireplumber` — provides `wpctl`
- `pipewire-pulse` — provides `pactl`, `paplay`
- `playerctl`

### Display / Input
- `brightnessctl`
- `udevadm` — brightness monitoring (part of systemd)

### Network
- `networkmanager` — provides `nmcli`
- `rfkill` — bluetooth toggle
- `dbus-monitor` — bluetooth state monitoring
- `iproute2` — provides `ip monitor`

### Battery
- No external tools required — battery state is read directly from `/sys/class/power_supply/BAT0/`
- If your battery path differs, update `BAT=/sys/class/power_supply/BAT0` in `battery-listener.sh`

### Power Management
- `tuned` + `tuned-adm`
- CPU governor — direct `/sys` writes via sudo (no extra package)
- `sysctl` — lazy mode (part of procps-ng)
- `systemctl` — shutdown/suspend/reboot

### Theming
- `pywal` — command: `wal`

### Wallpaper
- `swaybg`
- `mpvpaper` — optional, only needed for live wallpapers
- `imagemagick` — `convert` / `magick`, used for wallpaper thumbnails + eww icon cache
- `librsvg2-tools` — `rsvg-convert`, SVG icon conversion (optional but recommended)

### Clipboard
- `wl-clipboard` — provides `wl-paste`, `wl-copy`
- `cliphist`

### Screenshots
- `grim`
- `slurp`

### Music
- `mpv`

### Shortcuts Widget
- `python3`
- `rofi`
- `imagemagick` and/or `librsvg2-tools`

### Scheduling
- `at` + `atd` daemon — used in `schedule_action.sh`
- Enable the daemon: `sudo systemctl enable --now atd`

### VNC (optional)
- `wayvnc`

### Polkit
- `polkit-mate-authentication-agent-1` — required for authentication, cannot be bypassed

### Terminal / File Manager
- `konsole`
- `dolphin`

### Calendar Widget
- `khal` — calendar backend
- `vdirsyncer` — Google Calendar sync
- `python3-holidays` — public holiday data

### Misc
- `notify-send` — part of `libnotify`
- `inotify-tools` — provides `inotifywait`, required for turbo/governor/tuned deflisten triggers
- `dbus-update-activation-environment`
- `bash`, `python3`, `awk`, `sed`, `grep`, `find` — standard
- `python3-gobject`, `gtk4`, `libadwaita`, `socat`


# Sudo / Permissions
Several scripts in this config interact with system-level files — things like switching CPU governors, toggling turbo boost (for Intel CPUs), changing tuned profiles, and modifying `/etc/sysctl.conf`. These require sudo access.

## Step 1 — Add your user to the wheel group
`wheel` is the group that grants sudo access on Fedora/RHEL-based systems. On Debian/Ubuntu, the equivalent group is `sudo`.

```bash
sudo usermod -aG wheel YOUR_USERNAME
```

Log out and back in for the group change to take effect.

## Step 2 — Configure sudoers via visudo
`visudo` is the only safe way to edit the sudoers file — it validates syntax before saving, so you can't accidentally lock yourself out.

```bash
sudo visudo
```

A typical Fedora sudoers file looks like this:

```
## Sudoers allows particular users to run various commands as
## the root user, without needing the root password.
##
## This file must be edited with the 'visudo' command.

## Allow root to run any commands anywhere
root    ALL=(ALL)       ALL

## Allows people in group wheel to run all commands
%wheel  ALL=(ALL)       ALL

## Same thing without a password
# %wheel        ALL=(ALL)       NOPASSWD: ALL

## Read drop-in files from /etc/sudoers.d
#includedir /etc/sudoers.d
```

## Step 3 — Add the NOPASSWD rules for this config
At the bottom of the sudoers file, add this line (replace `YOUR_USERNAME` with your actual username):

```
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend, /usr/bin/systemctl poweroff, /usr/bin/systemctl reboot, /usr/bin/tuned-adm profile *, /usr/bin/tee, /sys/devices/system/cpu/intel_pstate/no_turbo, /usr/sbin/sysctl, /usr/bin/sed, /usr/bin/at, /usr/bin/atrm
```

This allows the eww scripts to toggle turbo boost, switch CPU governors, change tuned profiles, and apply sysctl settings without prompting for a password every time.

> Always use `visudo` — never edit `/etc/sudoers` directly. A syntax error will break sudo entirely.


# Lazy Mode
Lazy Mode is a battery saving toggle that appears in the battery popup menu. It works by commenting/uncommenting `vm.dirty_writeback_centisecs` in `/etc/sysctl.conf`. This value controls how often the Linux kernel flushes dirty pages (pending writes) from RAM to disk. By increasing this interval, the disk wakes up less frequently — which saves power, especially on battery.

## When does it appear?
The battery popup shows either Turbo Mode or Lazy Mode — never both at the same time:

- **Turbo Mode** appears when the system supports Intel pstate Turbo Boost — detected by the presence of `/sys/devices/system/cpu/intel_pstate/no_turbo`. This is Intel-specific and won't exist on AMD systems or systems without pstate support.
- **Lazy Mode** appears when Turbo Boost control is not available — i.e. the file above doesn't exist. This makes it useful on AMD systems, older Intel systems, or any machine where Turbo control isn't exposed.

The reason they're mutually exclusive is that Intel's Turbo Boost management already handles power states — running Lazy Mode on top of it would be redundant and can break the performance flow.

## What it does under the hood

**ON** — uncomments the line in `/etc/sysctl.conf` and applies it live:
```
vm.dirty_writeback_centisecs = 750
```
The kernel flushes dirty pages every 7.5 seconds instead of the default 5 seconds. Fewer disk wakeups, slightly better battery life.

**OFF** — comments the line out and reverts the kernel to the default:
```
vm.dirty_writeback_centisecs = 500
```
Changes are applied live via `sysctl` without a reboot.


# Calendar Widget Setup

## Step 1 — Install dependencies

```bash
sudo dnf install khal
pip install vdirsyncer[google] --user
pip install holidays --user
```

If `pip install` fails due to system Python restrictions, use:

```bash
pip install --break-system-packages vdirsyncer[google] holidays
```

Verify vdirsyncer is available:

```bash
vdirsyncer --version
```

Make sure `~/.local/bin` is in your `$PATH`. On Fedora 43 it should be by default.

---

## Step 2 — Configure khal

```bash
khal configure
```

Follow the interactive prompts. When asked for your calendar directory, use:

```
~/.local/share/calendar/
```

This creates `~/.config/khal/config`. The final config should look like this:

```ini
[calendars]

[[google]]
path = ~/.local/share/calendar/yourusername@gmail.com/
type = calendar

[[holidays]]
path = ~/.local/share/calendar/cln2sqbechkm2rh3d1nmoqb4c5sk0pridtqn0bjm5phm2r35dpi62shectnmuprccknr66rrd@virtual/
type = calendar

[locale]
timeformat = %H:%M
dateformat = %d/%m/%Y
longdateformat = %d/%m/%Y
datetimeformat = %d/%m/%Y %H:%M
longdatetimeformat = %d/%m/%Y %H:%M

[default]
default_calendar = google
```

Replace `yourusername` with your actual username.

---

## Step 3 — Google Cloud Console setup

vdirsyncer uses OAuth2 to access Google Calendar. You need to create credentials in Google Cloud Console.

### 3.1 — Create a project

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown at the top → **New Project**
3. Name it anything (e.g. `vdirsyncer`) → **Create**
4. Make sure the new project is selected in the top dropdown

### 3.2 — Enable the Google Calendar API

1. Go to **APIs & Services → Library**
2. Search for **Google Calendar API** → click it → **Enable**

### 3.3 — Configure the OAuth consent screen

1. Go to **APIs & Services → OAuth consent screen**
2. Choose **External** → **Create**
3. Fill in the required fields:
   - **App name**: anything (e.g. `vdirsyncer`)
   - **User support email**: your Gmail address
   - **Developer contact email**: your Gmail address
4. Click **Save and Continue** through the Scopes page (no changes needed)
5. On the **Test users** page:
   - Click **Add Users**
   - Add your own Gmail address
   - This is required — only listed test users can authenticate while the app is in testing mode
6. Click **Save and Continue** → **Back to Dashboard**

> The consent screen will show an "unverified app" warning during login. This is expected for personal OAuth apps that haven't gone through Google's verification process. Since you are the test user on your own project, click **Continue** to proceed past the warning.

### 3.4 — Create OAuth credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. Application type: **Desktop app**
4. Name it anything → **Create**
5. Copy the **Client ID** and **Client Secret** from the popup

---

## Step 4 — Configure vdirsyncer

Create the config directory and file:

```bash
mkdir -p ~/.config/vdirsyncer
nano ~/.config/vdirsyncer/config
```

Paste the following, replacing `YOUR_CLIENT_ID` and `YOUR_CLIENT_SECRET` with your credentials from Step 3.4:

```ini
[general]
status_path = "~/.local/share/vdirsyncer/status/"

[pair google_calendar]
a = "google_local"
b = "google_remote"
collections = ["from b"]

[storage google_local]
type = "filesystem"
path = "~/.local/share/calendar/"
fileext = ".ics"

[storage google_remote]
type = "google_calendar"
token_file = "~/.config/vdirsyncer/google_token"
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_CLIENT_SECRET"
```

Create the status directory:

```bash
mkdir -p ~/.local/share/vdirsyncer/status/
```

---

## Step 5 — Authenticate with Google

Run the discover command:

```bash
vdirsyncer discover google_calendar
```

vdirsyncer will print an OAuth URL in the terminal. Copy it and open it in your browser:

1. Choose your Google account
2. You'll see **"Google hasn't verified this app"** — click **Continue** (this is your own app, it is safe)
3. Grant calendar read access
4. Google will redirect to `localhost` — the page will fail to load, this is expected
5. Copy the full URL from your browser's address bar and paste it back into the terminal when prompted

vdirsyncer saves the token to `~/.config/vdirsyncer/google_token`. You won't need to log in again unless the token expires or is revoked.

---

## Step 6 — Sync and verify

Run the initial sync:

```bash
vdirsyncer sync
```

This pulls your Google Calendar events down as `.ics` files into `~/.local/share/calendar/`. A folder named after your Google account will appear there.

Verify khal can read the events:

```bash
khal list
```

---

## Step 7 — Clear khal's cache (if needed)

If khal was run before syncing and shows stale or empty data, delete its cache and let it rebuild:

```bash
rm -rf ~/.local/share/khal/
khal list
```

khal regenerates the cache automatically on the next run.

---

## Step 8 — Keep it synced automatically

vdirsyncer doesn't run in the background — you need to trigger it. Set up a systemd user timer to sync every 15 minutes.

Create the service file:

```bash
mkdir -p ~/.config/systemd/user/
nano ~/.config/systemd/user/vdirsyncer.service
```

```ini
[Unit]
Description=vdirsyncer calendar sync

[Service]
Type=oneshot
ExecStart=/home/YOUR_USERNAME/.local/bin/vdirsyncer sync
```

Create the timer file:

```bash
nano ~/.config/systemd/user/vdirsyncer.timer
```

```ini
[Unit]
Description=Run vdirsyncer every 15 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

Enable and start it:

```bash
systemctl --user enable --now vdirsyncer.timer
```

Check it is running:

```bash
systemctl --user status vdirsyncer.timer
```

Replace `YOUR_USERNAME` with your actual username in the service file.

---

## Test the calendar widget

```bash
python3 ~/.config/eww/calendar.sh
```

If it outputs JSON without errors, the widget is ready. khal must be configured and synced first — if neither has been done, the script will fail.

---

## Full flow summary

```
Google Cloud Console
  → Enable Calendar API
  → OAuth consent screen → add yourself as test user
  → Create credentials → copy client_id + client_secret

~/.config/vdirsyncer/config
  → paste client_id + client_secret

vdirsyncer discover google_calendar
  → opens browser → log in → accept warning → paste redirect URL → token saved

vdirsyncer sync
  → pulls .ics files into ~/.local/share/calendar/

khal list
  → reads from local .ics files → shows events

rm -rf ~/.local/share/khal/   ← only if cache is stale
  → khal rebuilds on next run
```


# Notes
- Run `chmod +x` on all `.sh` script files before use.
- Hardcoded paths use `/home/rohan/` — change these to your actual username before use.
- Wallpaper path is set in `~/.config/hypr/shellwrapper.sh`.
- eww icon cache (`~/.config/eww/icons/`) is gitignored — regenerates automatically on first run of `shortcuts-add.sh`.
- Icons must be PNG only and a fixed size — eww doesn't support dynamic icon sizing. Place them in `~/.config/icons/`.
- You can use any font you have installed — just update the font name in the config. The font used in this setup is included.
- This config is not Fedora-exclusive — it works on any distro with the required tools available.


# Battery Saving (For Intel Systems)

These tweaks reduce CPU wakeups and improve battery life on Intel laptops.

## Audio codec power management

Run once to create the config:

```bash
echo 'options snd_hda_intel power_save=1' | sudo tee /etc/modprobe.d/audio_powersave.conf
```

Takes effect on next reboot. This alone can noticeably reduce idle wakeups on Intel systems.

## Dirty writeback interval

Open `/etc/sysctl.conf`:

```bash
sudo nano /etc/sysctl.conf
```

Add this line (commented out by default — managed automatically by Lazy Mode):

```
# vm.dirty_writeback_centisecs = 750
```

Apply without rebooting:

```bash
sudo sysctl -p
```

## Changes done to battery-widget:

Battery state is read directly from `/sys/class/power_supply/BAT0/` using kernel sysfs instead of `upower` now. Reads are plain file reads against kernel memory, so there is no subprocess overhead per poll cycle.

If your battery is not at `BAT0`, check with:

```bash
ls /sys/class/power_supply/
```

Then update the `BAT=` line at the top of `battery-listener.sh` accordingly.
