# Quickshell bar: notes for Claude

The user's status bar, written in Quickshell (QML). It replaced Waybar on 2026-11-11 and is
**finished**; future work is maintenance and new features. It started as a 1:1 Waybar port
(`~/.dotfiles/waybar/.config/waybar/`, still installed as a fallback), but the user changed a lot
on purpose. **This file describes the current bar. Where it differs from Waybar, this file wins.**
Don't "fix" things back to Waybar's behaviour.

## Environment (checked 2026-11-11)

- Quickshell **0.3.2** (Arch), Qt 6.12, Hyprland **0.57.x** with a **Lua** config.
- Monitors: laptop `eDP-1` (1920x1200, sits at **y=2160** in the global layout; its scale changes,
  currently 1.25), sometimes an external `DP-6` (3840x2160, scale 1.25). There is one bar per screen.
- Stow: `~/.config/quickshell` → `~/.dotfiles/quickshell/.config/quickshell`. Edit the repo path.
- Font: **JetBrainsMono Nerd Font**, bold, 16px (`/usr/share/fonts/TTF/JetBrainsMonoNerdFont-*.ttf`).
- Tools: `grim`, `jq`, `hyprctl`, `nmcli`, `bluetoothctl`, `wpctl`, `playerctl`, `pfetch`, `fastfetch`,
  `python3` with `fontTools` and `PIL`.

## Running, reloading, logs

- Hyprland starts the bar at login (`hypr/.config/hypr/categories/autostart.lua`:
  `QT_LOGGING_RULES=qt.qpa.wayland.textinput=false qs`).
- **Saving a .qml file hot-reloads the running bar.** Keep every save loadable.
- Restart: `rw` (= `scripts/reload_bar.sh`: `qs kill`, wait, start via Hyprland). Foreground with log:
  `rwd` (`scripts/reload_bar_debug.sh`). Log of the running bar: `qs log`.
- Known harmless log lines (not ours):
  - `qt.qpa.wayland.textinput` when a tray menu takes focus (silenced at start)
  - `quickshell.dbus.properties` errors from Firefox/WebCord MPRIS or tray items
  - occasional `Pipewire error ... code -14` when an audio device disappears
- Waybar fallback: `qs kill; waybar &`. Its config is untouched, but its helper scripts
  (`mediaplayer.sh`, `mkstyle.sh`, `cpu_temp.sh`, `reload_waybar*.sh`) are in `scripts/unused/`.
- Always leave the user with a running bar, and say which bar runs.

## File map

| File | What it is |
|---|---|
| `shell.qml` | Entry: one `PanelWindow` per screen (top, height 64, exclusive zone, transparent). Left/centre/right `Row`s, plus one `TooltipHost`. Centre row: centred, but slides to avoid the sides; the window title gets the leftover width and hides below 80px; `Media.maxWidth` = centre space. Clipboard is hidden on eDP-1 when scaled (`screen.devicePixelRatio > 1`). |
| `Theme.qml` | Singleton: live pywal colours (`~/.cache/wal/colors.json`, FileView watch, fallback palette), geometry, opacity, animation durations, workspace and calendar colours, `contrast()`, `readable()`, `pillBackdrop`. |
| `Run.qml` | Singleton: `sh(cmd)`, `floating(cmd)` (toggling kitty popup), `dispatch(lua)` (`hyprctl dispatch`). |
| `TooltipState.qml` | Singleton: which item wants the shared tooltip (`request/update/release/drop`, 200 ms hang). |
| `components/PillGroup.qml` | A joined pill: one rounded rect (bg at `pillOpacity`, 2px `color0` border) with `Segment`s in a `Row`. |
| `components/Segment.qml` | One module in a pill: padding, animated width, hover, `clicked`/`scrolled` signals, `tooltip` (text) or `tooltipComponent` (rich). |
| `components/BarText.qml` | `Text` with the bar font. Use it for every label and icon. |
| `components/FancyText.qml` | Changing text: cross-fade, `maxChars` and `maxWidth` truncation with `…`, marquee while hovered. |
| `components/InfoTable.qml` | Standard tooltip body: hint lines, then label/value rows with right-aligned values, ending 16px (`overhang`) past the widest hint. |
| `components/Tooltip.qml` | Asks the shared tooltip for any `target` Item (Segment uses it; tray icons and workspace buttons use it directly). |
| `components/TooltipHost.qml` | The shared tooltip box (see "Tooltip system"). |
| `components/WifiIcon.qml` | Line-style wifi drawn with QtQuick.Shapes: `level` 0–4 lit arcs, `slashed`, `size` (13px). |
| `components/BadgeIcon.qml` | Full-size glyph with a small badge glyph; a ring is knocked out behind the badge (MultiEffect mask), so no dark disc shows. |
| `modules/ArchClock.qml` | `[arch \| clock]`. Arch: pfetch tooltip; click toggles fastfetch. Clock: calendar tooltip, scroll for months. |
| `modules/CalendarView.qml` | Calendar content (MonthGrid/DayOfWeekRow/WeekNumberColumn, en_GB, always 6 rows). |
| `modules/Workspaces.qml` | All workspaces of all monitors, sliding focus pill, per-button app-list tooltip. |
| `modules/Clipboard.qml` | Clipboard pill (cliphist via wofi). |
| `modules/WindowTitle.qml` | Focused window title (Wayland toplevel), "Desktop" fallback, tooltip = app class. |
| `modules/Media.qml` | `[prev \| art \| title \| next]` for **spotifast** only, with progress fill and cross-fades. |
| `modules/NetBt.qml` | `[network \| bluetooth]`, icons only, InfoTable tooltips. |
| `modules/Stats.qml` | `[cputemp \| memory \| battery]`. |
| `modules/Audio.qml` | `[volume \| mic]` via Pipewire. |
| `modules/Tray.qml`, `modules/tray/*` | System tray plus the custom pywal DBusMenu menu (TrayMenu / TrayMenuList / TrayMenuEntry). |

## How the bar behaves (current spec)

**Layout and look**
- Pills sit 20px from the top and are 44px tall. Outer corner radius 10, inner joins square, padding 10.
  Gaps of 10px between groups, 20px from the screen edges.
- Groups: left `[arch|clock] [workspaces] [clipboard]`, centre `[window] [media]`,
  right `[network|bluetooth] [cputemp|memory|battery] [volume|mic] [tray]`.
- **Opacity (final):** only the pill background is at 0.8; text, icons and border are fully opaque
  (`Theme.pillOpacity`, `Theme.contentOpacity`).
- **Colours** are pywal, live. Arch `color4`, clock `color3`, cputemp `color5` (`color1` at 80°C or more),
  memory/window/clipboard `foreground`, volume `color4`, mic `color5`. Network `color3`, bluetooth `color4`
  and battery `color2` go through `Theme.readable(c, 4.5)` (lightened, same hue, to WCAG 4.5:1 against
  `pillBackdrop` = background at 0.8 over a mid-grey wallpaper). The calendar uses hardcoded Waybar colours
  (`Theme.cal*`).

**Modules**
- **Arch:** tooltip = coloured pfetch preview (ANSI → pywal), 6px extra vertical padding, no hint line.
  pfetch runs on hover only. Click toggles `kitty --class floating -o font_size=11 bash -c 'fastfetch; read -rsn1'`.
  The system menu is no longer on the bar; its old command is in a comment.
- **Clock:** `%R  %a, %-d. %b` with Waybar's glyphs (`SystemClock`): always one space after the comma
  (Waybar's `%e` padding left no space on two-digit days). Tooltip = calendar (always 6 rows,
  "Month Year" header, ISO weeks on the right, today highlighted). While it is open, scrolling on the
  clock changes the month: 240 angleDelta per month plus a 250 ms cooldown (`wheelCooldownMs`). It resets
  on close.
- **Workspaces:** **all** normal workspaces from every monitor, sorted by id (Waybar showed only its own
  output). Text: inactive `color8`, visible-on-a-monitor `foreground`, hover `foreground`; urgent gets a
  `color2` background with `color0` text. A rounded **focus pill** (`Theme.wsPill`, color5 at about 0.35)
  slides 280 ms to the focused workspace and fades only on special workspaces. Click activates (Lua-aware
  `activate()`). Hover tooltip: the apps on that workspace with icons and desktop-entry names
  ("Firefox", `kitty ×2`); none for an empty workspace. Button padding stays 5px (the user rejected 8).
- **Clipboard:** `pkill wofi || cliphist list | wofi … | cliphist decode | wl-copy`. Right padding 12.
  Hidden on eDP-1 when it is scaled.
- **Window title:** max 40 chars, plus elision by pixel width when space is short; the marquee runs on
  hover only; hidden when it has less than 80px.
- **Media:** only the MPRIS player whose `dbusName` starts with `org.mpris.MediaPlayer2.spotifast`
  (playerctld also claims identity "Spotifast"). Title = `<play/pause> <title> - <artist>`, max 20 chars
  (icon included), elides further if the centre is full. The progress fill animates; the timer runs only
  while playing. Art cross-fades; clicking the art focuses workspace 9. The group collapses to
  `[prev|next]` without a player, or when stopped.
- **Network:** a single **drawn line-style wifi icon** (lit arcs = 0–4 bars, slashed when disconnected),
  `md-wifi_alert` when disabled or linked without IP, ethernet glyphs for wired. InfoTable tooltip: SSID,
  signal %, IP/CIDR (nmcli, on change), interface, fixed-width up/down rates (`/proc/net/dev`, sampled only
  while hovered). Left click nmtui, right click `btop -p 4`.
- **Bluetooth:** one icon: `md-battery_N_bluetooth` when the device reports a battery; headphones/speaker +
  bluetooth badge (`BadgeIcon`) for audio devices without battery info (the AirPods); struck-through
  `md-bluetooth_off` when on but nothing is connected; `md-alert` when off, blocked or without a controller.
  The tooltip has controller, address, state and devices. Click bluetuith.
- **CPU temp:** coretemp package temp (hwmon path resolved at start), sampled every 2 s. Tooltip: usage,
  frequency (`/proc/cpuinfo`), top process by CPU (per-core %, `/proc` deltas, only while shown).
  Click `btop -p 1`.
- **Memory:** used % from `/proc/meminfo` every 5 s. Tooltip: used/total GiB, swap, top process by RSS.
  Click `btop -p 3`.
- **Battery:** ramp icon + %, or the plug icon + % on AC. Warning (30% or less) `color3`, critical (20% or less)
  `color1`, both through `readable()`. **Pulse** (opacity 1 → 0.45, 1.6 s) only while critical **and**
  discharging; this is the only allowed constant animation. Tooltip: hint `Change Power Settings: 󰍽`,
  then Performance (`normal`, a placeholder for `PowerProfiles.profile`), Time to empty/full (or `Full`/`–`),
  Power draw/Charge rate (or `–`). Nothing else: the user found more too much. The sysfs code for
  health/cycles/etc. still exists but is unused. Left click is a TODO stub for future power settings.
  `batteryOverride` is a test hook.
- **Volume/mic:** Pipewire (`PwObjectTracker`). Volume shows ramp/headphone icon + % or `󰝟 Muted`; mic
  shows ` %`. Click mutes; right click opens wiremix (playback/recording tab); scroll is
  **inverted like Waybar** (up = −1%), capped at 100%, touchpad deltas accumulated. The tooltips show only
  the hints + device name (the % is already in the pill).
- **Tray:** all items (passive too), 18px icons, per-icon tooltips. Left = activate, middle = secondary,
  scroll, right = **custom pywal menu** (separators, check/radio, icons, inline submenus, closes on an
  outside click or Escape).

**Tooltip system** (one per bar, `TooltipHost`)
- The first show waits 400 ms. While a tooltip is open (or for 200 ms after leaving a pill), the next one
  opens at once, and the box **glides and resizes** to the new pill with a text cross-fade (220 ms).
- Open: the box starts at the pill's width minus the 10px corners (minimum 20px), hidden behind the pill's
  bottom edge, then slides down 8px while growing and fading in (220 ms OutCubic). Close: the reverse
  (150 ms InCubic).
- Centred under the pill, kept at least 8px from the screen edges (the user rejected 20px).
- Drawn on an overlay **layer surface** (namespace `quickshell-tooltip`, click-through, mapped only
  while shown). Don't use `PopupWindow`: Hyprland draws it 4px off.
- Content: `Segment.tooltip` (text), or `tooltipComponent` (an Item; the host pads it 12/8px and refits
  when its implicit size changes). Data tooltips use `InfoTable`.

**Tooltip content rules (from the user)**
- Hint lines like `Open X: 󰍽` come first. Keep the exact glyphs (left click `` + `󰍽`, right
  click `󰍽` + ``).
- **Never show the same info in the pill and its tooltip.**
- Values that tick are **fixed-width** (padStart, monospace), so the box doesn't jump.
- Processes (ps/top/nmcli/pfetch) run **only while their tooltip is shown or the pill is hovered**.

**Popups launched from the bar**
- `Run.floating(cmd)` runs `kitty -o confirm_os_window_close=0 --class floating --instance-group qsbar-<key> <cmd>`.
  A second click on the same item closes that window (`pkill -f '^kitty .*--instance-group <key>'`).
  Keep `--class floating`: Hyprland floats and centres it at `FLOAT_SIZE`, **1032x645 (16:10)**, in
  `hypr/.config/hypr/categories/windowrules.lua` (used by every floating rule).
- Dispatch Hyprland in Lua syntax: `Run.dispatch('hl.dsp.focus({ workspace = 9 })')`.

## Code conventions

- One component per file. Shared look lives in `components/`; never duplicate pill or tooltip styling.
- Colours only from `Theme` (pywal, live). Don't hardcode pywal colours. Use `Theme.readable()` for any
  pywal colour that is too dark as text.
- Animations 150–400 ms, `Easing.OutCubic`, only on change. Nothing runs while idle (Timers bound to a
  condition such as playing, hovered or tooltip shown). Polling only for /proc and sysfs (1–5 s).
- No polling where an event source exists (MPRIS, Pipewire, Hyprland IPC, UPower, Networking, Bluetooth).
- Nerd Font glyphs: verify them in the font (`fontTools` cmap / glyph names), and write them as `"\uXXXX"`
  or `String.fromCodePoint(0x…)`. Some source lines contain invisible private-use glyphs, so match them
  with regex or `cat -A` when editing by script.
- Strings: use `[...str]`, not `Array.from(str)` (Qt splits emoji).

## Testing and verification

- After every change: read `qs log` (no new warnings from our files), then take a screenshot and look at it:
  `grim -g "0,2160 1920x70" <scratchpad>/bar.png`. Use `-s 2` for detail. Check `hyprctl monitors -j`,
  because the offset and scale change; with eDP-1 at scale 1.25 the bar is 1536 logical px wide.
- **Hidden harness** (logic and load errors, no screen effect): a scratch dir with symlinks to `Theme.qml`,
  `Run.qml`, `TooltipState.qml`, `components/`, `modules/`, and a `shell.qml` with a `visible: false`
  PanelWindow. Run it with `timeout 6 qs -p <dir> --no-color`. Hidden windows do no Row layout and run no
  animations, so widths look stale there.
- **Visible harness** (tooltips, popups, icons): a top `WlrLayer.Overlay` PanelWindow with
  `ExclusionMode.Ignore` plus a `TooltipHost { bar: … }`. Call
  `TooltipState.request(seg, "", seg.tooltipComponent)`, run it with `timeout 3–4`, and take a grim
  screenshot. It flashes on the user's screen, so use it rarely.
- A squeezed copy of `shell.qml` (anchors top+left, `implicitWidth: 1450`, overlay) tests the full-bar layout.
- Hover, animation feel and clicks still need the user's eyes; ask them.
- Never trigger side effects while testing (playback, volume, workspace switching, tray entries, network
  or bluetooth toggles). Opening a floating kitty to check its size is fine if you close it afterwards.

## Quickshell 0.3.2 gotchas

- `qmllint`: use `/usr/lib/qt6/bin/qmllint` (`/usr/bin/qmllint` is Qt 5). It is noisy with `import qs`;
  the `qs` log is the real check.
- Singletons: `pragma Singleton` + `Singleton` root, no qmldir. Subfolders use `import qs` / `import qs.components`.
- `Variants { model: Quickshell.screens }` (not `variants:`).
- `Hyprland.activeToplevel` is null until the first focus event; use `ToplevelManager.activeToplevel`.
  `HyprlandWorkspace.activate()` works with the Lua config. `HyprlandMonitor.scale` reads 0; use
  `ShellScreen.devicePixelRatio` (fractional scales round up: 1.25 → 2).
- Hyprland focus changes arrive as unfocus-old / focus-new in **no fixed order**, and empty workspaces get
  destroyed. Never treat "briefly nothing focused" as "hidden" (that was the sliding-pill bug).
- MPRIS `position` isn't reactive: call `positionChanged()` from a Timer that runs only while playing.
- Pipewire: bind nodes with `PwObjectTracker`. Volume uses the cubic scale (like wpctl) and can go above 1.0.
- UPower %, Bluetooth battery and Wifi signal are **0..1**. Quickshell.Networking has no IP or bandwidth.
  Bluetooth has no controller MAC (use `busctl … org.bluez.Adapter1 Address`). AirPods expose no BlueZ battery.
- `execDetached`/`Process` run no shell: use `Run.sh` / `["sh","-c",…]`.
- `PopupWindow` is drawn 4px off by Hyprland, and resizing it stutters: use overlay `PanelWindow`s with a
  fixed size, animate an inner item, and set `mask: Region {}` for click-through.
- Calendar controls: `QtQuick.Controls`, `locale: Qt.locale("en_GB")` for Monday first. When the 1st is a
  Monday, `MonthGrid` starts a week early (CalendarView corrects for it). Its grid skips invisible items,
  so blank cells keep empty text rather than `visible: false`.
- `Loader { active: sourceComponent !== null }` causes a binding loop; a Loader without a component is
  simply empty.
- FileView works on /proc and sysfs (`reload()` from a Timer).

## Git

The repo's root `CLAUDE.md` applies: commit only when asked, use the user's message exactly, and
**never** add Claude/AI attribution or `Co-Authored-By` trailers. The user has unrelated uncommitted
changes (waybar, nvim lock, btop, waypaper, scripts, autostart.lua). Stage only what belongs to the task.

## Status (2026-11-11)

- [x] Phases 1–3 done and reviewed by the user; cutover from Waybar done.
- [x] Cutover edits outside this folder:
  - `autostart.lua` starts qs
  - `scripts/reload_bar.sh` and `scripts/reload_bar_debug.sh` added
  - `reload_waybar*.sh`, `mediaplayer.sh`, `mkstyle.sh` and `cpu_temp.sh` moved to `scripts/unused/`
  - `zsh/.zshrc` `rw`/`rwd` updated
  - `system_menu.sh`: the "Waybar" entry became "Bar"
  - README package list: `quickshell` added
  - `windowrules.lua`: `FLOAT_SIZE` 16:10
- [ ] **Nothing is committed yet.** Commit only when the user asks.
- Open ideas, not requested yet:
  - power settings behind the battery click (Performance row from `PowerProfiles`)
  - the system menu could go on the arch right-click
  - the album art cross-fade, the collapse when Spotifast closes, and the urgent workspace style have not
    been seen by the user yet
