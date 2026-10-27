<h1 align="center">Tide Island Extended</h1>

<p align="center">
  <b>A compositor-agnostic Wayland fork of Tide Island Extended.</b>
</p>

<p align="center">
  <a href="https://github.com/Bimbok/Tide-island-extended"><img alt="Upstream: Bimbok/Tide-island-extended" src="https://img.shields.io/badge/upstream-Bimbok%2FTide--island--extended-8aadf4?style=flat-square"></a>
  <a href="https://github.com/enhaoswen/Tide-island"><img alt="Upstream: enhaoswen/Tide-island" src="https://img.shields.io/badge/upstream-enhaoswen%2FTide--island-8aadf4?style=flat-square"></a>
  <img alt="Wayland" src="https://img.shields.io/badge/Wayland-111111?style=flat-square&color=8aadf4">
  <img alt="C++ + Qt" src="https://img.shields.io/badge/C%2B%2B%20%2B%20Qt-111111?style=flat-square&color=8aadf4">
</p>

<p align="center">
  <b>Upstreams:</b> <a href="https://github.com/Bimbok/Tide-island-extended">Bimbok/Tide-island-extended</a>, itself a fork of <a href="https://github.com/enhaoswen/Tide-island">enhaoswen/Tide-island</a>
</p>


<p align="center">
  <a href="#how-this-fork-differs">Fork differences</a>
  ·
  <a href="#preview">Preview</a>
  ·
  <a href="#features">Features</a>
  ·
  <a href="#performance--resource-efficiency">Performance</a>
  ·
  <a href="#installation">Installation</a>
  ·
  <a href="#configuration">Configuration</a>
  ·
  <a href="#common-commands">Common Commands</a>
  ·
  <a href="#acknowledgments">Acknowledgments</a>
</p>

---

## About Tide Island Extended

Tide Island Extended is a desktop widget for Wayland compositors, styled like the Dynamic Island.
This repository is a fork of [Tide Island Extended](https://github.com/Bimbok/Tide-island-extended)
by [@Bimbok](https://github.com/Bimbok), which is itself a fork of [Tide Island](https://github.com/enhaoswen/Tide-island)
by [@enhaoswen](https://github.com/enhaoswen). It has no compositor-specific code; see
[Compositor support](#compositor-support) for what it needs and [How this fork differs](#how-this-fork-differs)
for what changed.

When nothing much is going on, it sits compactly at the top (or bottom) edge of the screen, staying out of the way: the clock, the playing track with its synced lyric, an unread-notification bell and, when wanted, the battery. When you need more, it expands into interactive panels to adjust system settings, check notifications, view weather or the calendar, and more.

It is built with Quickshell, QML, and C++/Qt 6. Animations are tuned to be fluid and responsive while keeping resource usage minimal.

> [!NOTE]
> ### About This Project
>
> **Tide Island Extended** is an independently maintained and enhanced fork of [Tide Island](https://github.com/enhaoswen/Tide-island), originally created by [**@enhaoswen**](https://github.com/enhaoswen).
>
> The original Tide Island project provided the core architecture, animation system, Dynamic Island concept, and foundation on which this project is built.
>
> **Tide Island Extended has its own development direction and codebase.** It is not intended to remain in direct sync with upstream. Selected ideas, features, fixes, or improvements from the original project may be incorporated when they are considered meaningful and suitable for this project, adapted and integrated into the codebase as needed.
>
> Beyond these upstream-inspired improvements, Tide Island Extended also introduces its own features, integrations, performance improvements, UI refinements, and other enhancements.

## How this fork differs

Compared with [Bimbok/Tide-island-extended](https://github.com/Bimbok/Tide-island-extended):

**Removed**

- Hyprland and niri integration: workspace capsule and overview, compositor focus tracking, generated shortcut files.
- The notch style, the app launcher, the wallpaper picker and the Matugen/pywal hooks.
- The built-in lockscreen; the power menu's Lock runs an external locker instead.

**Added**

- Tide Island is the notification daemon itself, so actions work and hand the app an xdg-activation token.
- Its own Do Not Disturb, kept across restarts (upstream used swaync's), and per-urgency pop-up durations.
- [`lockCommand`](#configuration) picks the screen locker; `idleInhibitCommand` adds a caffeine toggle.
- Resting-island battery modes (`islandBatteryMode`, `islandBatteryThreshold`) and an optional bottom edge (`islandEdge`).
- An option to keep the island above fullscreen windows (`islandAboveFullscreen`).
- Turning Bluetooth on lifts an rfkill soft block first.

**Changed**

- Screen recording uses wf-recorder instead of gpu-screen-recorder (no replay buffer or pause).
- The control center is always fully expanded, and a horizontal touchpad swipe flips between it and the Glance.
- Panels close on a click outside them, and the side popups (Wi-Fi, Bluetooth, audio, battery) fit their content.
- Faster animations and a colour pass that works with light palettes.
- Lower idle memory: rarely used panels load on first open and the lyrics daemon runs only during playback ([details](#performance--resource-efficiency)).
- The settings app writes only the keys you changed and refuses to overwrite an invalid file.


<br>

## Preview

### Dynamic Island Capsules

<table>
  <tr>
    <td width="33%" align="center">
      <img src="docs/preview/island_music_pill.png" width="100%" alt="Compact Music Pill" />
    </td>
    <td width="33%" align="center">
      <img src="docs/preview/notification.png" width="100%" alt="System Notification Preview" />
    </td>
    <td width="33%" align="center">
      <img src="docs/preview/notification_action.png" width="100%" alt="Interactive Notification Preview" />
    </td>
  </tr>
</table>

### Interactive Panels

<table>
  <tr>
    <td width="50%">
      <img src="docs/preview/music_player.png" width="100%" alt="Music Player" />
    </td>
    <td width="50%">
      <img src="docs/preview/timer.png" width="100%" alt="Timer" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/preview/control_center.png" width="100%" alt="Control Center" />
    </td>
    <td width="50%">

    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/preview/audio_panel.png" width="100%" alt="Audio Device Switcher & Application Mixer" />
    </td>
    <td width="50%">
      <img src="docs/preview/battery_panel.png" width="100%" alt="Battery Health & Charge Conservation Mode" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/preview/weather.png" width="100%" alt="Weather & Forecast" />
    </td>
    <td width="50%">
      <img src="docs/preview/calendar.png" width="100%" alt="Calendar & Notes" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/preview/clipboard.png" width="100%" alt="Clipboard History" />
    </td>
    <td width="50%">
      <img src="docs/preview/clipboard_preview.png" width="100%" alt="Clipboard Image Preview & File Shelf" />
    </td>
  </tr>
</table>

### Config App

<p align="center">
  <img src="docs/preview/config_app.png" width="95%" alt="Tide Island Extended Settings" />
</p>
<br>

## Features

### Extended Enhancements

- **Sleek Horizontal Scrolling System Tray (SNI)**: Embedded StatusNotifierItem tray widget with item count badge pill, smooth horizontal flick/wheel scrolling, 34×34 squircle icon tiles, edge fade gradient masks when overflowed, tooltips on hover, and full click/context menu interaction.
- **Screen Recorder**: Records the screen with `wf-recorder` (H.264 MP4, desktop audio or the microphone):
  - **Dynamic Active Elevation**: While recording, a recorder banner with a live timer appears in the Control Center.
- **Dynamic Color Palette**: Live hot-reloads of `colors.json` on disk via `QFileSystemWatcher` without service restarts, with preserved capsule translucency (`islandBackgroundOpacity`).
- **Dynamic Battery Color Progression**: Battery pill smoothly shifts colors based on charge level (critical, warning, nominal, charging) with palette color matching and an on/off toggle in settings.
- **Marquee Track Title Scrolling**: Clean, smooth auto-scrolling for long song titles with an initial 1.8s reading pause and seamless looping, in the expanded player; set `marqueeTrackTitleEnabled` to `false` in `userconfig.json` for a static ellipsis (`Title...`) instead.
- **Universal Keyboard Navigation & Dismissal**: Universal `Escape` key dismissal and keyboard navigation across all interactive panels (Control Center, Notification Center, File Shelf, Calendar, and Power Menu).
- **Asynchronous Clipboard & Concurrency Safety**: Fast asynchronous decoding for image clipboard entries and race-condition guards during clip deletions.
- **Interactive Control Center Sliders & Quick Corner Actions**:
  - **Microphone Intensity Slider**: Native input gain slider powered by WirePlumber (`@DEFAULT_AUDIO_SOURCE@`) with 40ms event throttling, fluid drags, and instant click-to-mute corner toggle.
  - **Click-to-Mute Sound Card**: One-click corner icon toggle for system audio (`@DEFAULT_AUDIO_SINK@`) with dynamic mute icon (`󰝟`), `"Sound (Muted)"` title indicator, and dimmed accent fill.
  - **Dynamic Sun Glyph & Brightness Presets**: Real-time morphing sun icon matching backlight level (`󰃞` <30%, `󰃟` 30%–70%, `󰃠` >70%) plus click-to-cycle presets (`10% ➔ 30% ➔ 65% ➔ 100% ➔ 10%...`).
- **Audio Device Switcher Flyout (Outputs & Inputs)**: Side flyout panel opened with one click on the chevron (`›`) on either the Sound or Microphone card:
  - **Output Devices**: Instantly switch default audio sink/port between Speakers, Headphones, Bluetooth earbuds, and HDMI with visual active indicator checkmarks.
  - **Input Devices**: Instantly switch active microphone source between Internal Mic, USB Mic, and Headsets.
  - **Sleek Tab Switcher**: Segmented pills (`[ Output | Input | Mixer ]`) allow seamless navigation between output devices, microphones, and per-app streams in place.
- **Per-App Volume Mixer**: Integrated PipeWire/WirePlumber application volume mixer:
  - Displays all active applications playing audio (Firefox, Spotify, Discord, Steam, games).
  - High-res desktop app icons resolved automatically via the freedesktop icon theme.
  - Compact individual volume sliders and one-click app mute toggles.
- **Battery Health, Charge Limit & Conservation Mode**: Direct hardware control for laptop battery lifespan preservation:
  - **Lenovo IdeaPad Conservation Mode**: Hardware-level 80% charge threshold integration via `ideapad_acpi` (`conservation_mode`), capping charge at 80% while plugged in to prevent battery wear.
  - **Generic Laptop Charge End Threshold**: Automatic support for standard Linux battery threshold interfaces (`charge_control_end_threshold`) with preset pills (`80%`, `85%`, `90%`, `100%`).
  - **Dedicated Battery Flyout Panel**: Opened by clicking the battery pill in the Control Center header, or the battery section of the resting island (as a standalone popup under the capsule).
  - **Live Battery Telemetry**: Real-time display of battery charge status, health percentage (`batteryHealthPercent`), cycle count (`batteryCycleCount`), and an active `80% Cap` badge.
  - **Zero-Latency Non-Blocking Control**: Asynchronous C++ backend paired with automated `systemd-tmpfiles` permissions (`tide-island-battery.conf`) for instantaneous toggling without root password prompts or UI freezes.
- **Symmetrical Flyout Architecture & Mutual Exclusivity**:
  - All side panels (Wi-Fi, Bluetooth, Audio, Battery) are 318 px wide and fit their content up to 404 px tall (longer lists scroll), with unified typography.
  - Clean mutual exclusivity automatically dismisses active sibling panels when a new flyout is opened, eliminating clutter.
- **Dedicated Microphone & Audio Dynamic Island OSD Feedback**: Real-time PipeWire audio source/sink monitoring (`pactl subscribe`) that keeps sliders in sync and shows an `[icon] [bar] [percent]` OSD (the bar dims while muted) whenever levels change via hotkeys, CLI commands, or UI clicks.
- **Throttled Slider Performance**: Event throttling on microphone, volume, and brightness slider drags to eliminate IPC and D-Bus lag, maintaining smooth 60fps+ responsiveness.
- **Unified Icon Weight Harmony**: Clean, consistent icon line weights across volume, microphone, brightness, battery, and weather.
- **Privacy & Media Activity Indicators & HUD**:
  - **Dynamic Island Activity Bubbles**: Independent circular satellite bubbles dynamically pop out on the right side of the island capsule when the camera (``) or microphone (`` / ``) are active, matching the File Shelf bubble aesthetic with pulsing status badges (green for camera, orange for active microphone, red when muted).
  - **Privacy & Media Activity HUD**: Interactive drop-down panel displaying applications currently capturing camera, microphone, or screen sharing with PID telemetry, quick one-click app mute/unmute or screen share stop controls, and a master hardware microphone mute toggle.
  - **Modal Dismissal & Focus**: Closes seamlessly via `Escape` key and click-outside dismissal, maintaining consistent focus behavior across Wayland compositors.
  - **Full Theme Harmony**: Automatically styled using `StyleTokens` to inherit your colors.json palette.
- **On-Demand System Glance Capsule & Dashboard**:
  - **Dynamic Island Mini Dashboard**: The island expands into a system glance dashboard displaying a circular avatar / profile picture (with auto-detection from ChillPill-Shell `displayPicture`, `userconfig.json` `"avatarPath"`, image drag-and-drop, or click-to-browse), hostname, system uptime, kernel release, rich multi-metric battery telemetry (`⚡ 71% • 80% Cap • 100% Health` with power wattage and full diagnostics tooltip), real-time network throughput (`↓ 5.2 MB/s`, `↑ 240 KB/s`), CPU load & core temperature, RAM utilization (`GB` and `%`), and GPU / Storage meters.
  - **100% On-Demand Sampling**: Sampling timers only run when the glance layer is visibly mounted; zero CPU overhead when hidden. No third-party monitor dependencies (e.g. `nusmon`), extracting metrics directly from standard Linux `/proc` and `/sys` interfaces.
  - **Intuitive Triggers & Controls**: Sleek modern aesthetic without intrusive close buttons — open it by swiping down on the resting island (a mouse drag, or two fingers on a touchscreen; swipe up when the island sits at the bottom edge), with a horizontal touchpad swipe from the Control Center, or with `quickshell ipc -p /usr/share/tide-island call tide toggleGlance` (bind it in your compositor); dismiss with `Escape`, a click outside, or the same toggle.

### Core Features

- Clock
- System Glance & Dashboard (swipe down on the island, or IPC)
- Music player
- Control Center
- Audio device switcher & per-app volume mixer
- Microphone control & mute toggle
- Battery health & charge limit (conservation mode)
- Timer (click the clock in the Control Center header)
- Synced lyrics in the resting island
- File shelf
- Clipboard history manager
- Weather & Forecast
- Calendar
- Notification Center
- Power menu
- System Tray (SNI)
- Screen Recorder

Clipboard history requires `cliphist` and `wl-clipboard`. Tide Island starts the clipboard watcher automatically while it is running.
Click a date in the calendar to write a note. Dates with notes show a small dot; notes are saved automatically.
Click the × button on a notification card to dismiss it, or use **Clear All** in the Notification Center to dismiss all notifications at once.

Notification pop-ups stay 8 s (low urgency 5 s; `notificationTimeout` / `notificationTimeoutLow`
in seconds), critical ones until dismissed, and an app's own expire timeout wins. Hovering a pop-up
pauses it. Clicking its body closes it and marks it read; the **Open** pill runs the app's default
action. The bell on the island counts unread notifications in the center; after a Quickshell
reload the re-sent notifications start read.



### System Feedback

- Volume & audio mute changes
- Microphone intensity & mute changes
- Brightness changes
- Battery charging / discharging & conservation limit
- System notifications



### Compositor support

Tide Island has no compositor-specific code. What it uses from the compositor:

- **wlr-layer-shell** (required): the island and its panels are layer surfaces on the top and overlay layers, with an exclusive zone. GNOME/Mutter doesn't offer it, so Tide Island doesn't run there.
- **Keyboard interactivity on layer surfaces** (exclusive and on-demand): `Escape`, keyboard navigation and text fields such as Wi-Fi passwords and calendar notes.
- **xdg-activation-v1**: a notification action hands the app an activation token tied to your click; whether the window is raised is up to the compositor, which must honour the token. Without the protocol, actions still run, just without a token.
- **wlr-screencopy** for the screen recorder, which is what wf-recorder captures through.
- **Data control** (`ext-data-control-v1` or `wlr-data-control`) for clipboard history, which `wl-paste --watch` needs.
- **ext-background-effect-v1** (optional) for the blur behind the island (`islandBlurEnabled`).
- **Overlay layer above fullscreen windows** (optional): with `islandAboveFullscreen` the island always sits on the overlay layer, but it only shows over a fullscreen window if the compositor draws overlay-layer surfaces above fullscreen ones.
- **Shortcuts**: Tide Island binds no keys itself; bind the [IPC commands](#ipc-commands) in your compositor's keybinding config.

Each output gets its own island, but the shell can't ask the compositor which output has focus, so a
panel opened by IPC always appears on the first island.

<br>

## Performance & Resource Efficiency

Tide Island Extended is engineered to deliver fluid 60fps+ animations while maintaining a negligible CPU and memory footprint on your system:

Measured offscreen (software rendering, one screen), the shell process uses about 93 MB PSS at
idle and about 108 MB after every panel has been opened once. Rarely used panels (notification
center, file shelf, clipboard, weather, calendar, privacy HUD, glance) are compiled on first open.

Background helpers: `dbus-monitor` (ScreenCast portal only; Tide Island is the notification
server itself), `pw-mon` (privacy indicators), `pactl subscribe` (volume OSD) and the
`cliphist` watcher. `cava` runs only while the resting music section, or the expanded player's
music page during playback, is on screen, and the `lyricsmpris` lyrics daemon only while a player
is playing (plus a minute after it pauses).

### Architectural Optimizations
- **Direct Telemetry**: The glance reads `/proc` and `/sys` directly instead of spawning `free`, `df` or `top`.
- **Retina Image Decode Bounding**: All dynamic image elements (MPRIS high-res album covers, user avatars, notifications, and clipboard previews) specify explicit `sourceSize` bounds. 4K/8K images are downsampled at decode time, preventing multi-megapixel raw bitmaps from inflating memory.
- **Apps outside the shell's cgroup**: Programs Tide Island starts for you (`xdg-open`, links, the screen recorder, the screen locker, terminals, the settings app) run in their own transient systemd scope, so restarting the shell never takes them down.
- **Declarative Animation**: Motion uses Qt Quick's declarative animations rather than JavaScript timers. The audio visualizer bars follow cava's levels through short height animations, with no free-running phase loop.

<br>

## Installation

### From Source (All Distributions)

Clone this repository and run the automated installer from the clone:

```bash
./install.sh
```

The installer builds Tide Island, writes it to `/usr`, registers desktop and service files, and automatically handles dependencies on:

- **Arch Linux, EndeavourOS, Manjaro, CachyOS** (using `pacman`)
- **Debian, Ubuntu, Linux Mint, Pop!_OS** (using `apt`)
- **Fedora, RHEL, Nobara** (using `dnf`)
- **openSUSE** (using `zypper`)

> [!TIP]
> If you previously installed the older AUR `tide-island` package, remove it before running the installer:
> ```bash
> sudo pacman -R tide-island
> ./install.sh
> ```

For other distributions, install dependencies manually and run:

```bash
./install.sh --skip-deps
```

Quickshell is used from `/usr/bin/quickshell` when available. Otherwise the installer builds the pinned, verified Quickshell version compatible with this release. Qt 6.6 or newer is required.

Useful installer options:

| Flag / Option | Description | Notes |
| :--- | :--- | :--- |
| `--check-deps` | Audits the system and prints a status check for all mandatory and optional dependencies. | Non-destructive; requires no `sudo`. |
| `--skip-deps` | Skips automatic distribution package manager dependency installation. | For manual installs or unsupported distros. |
| `--skip-quickshell` | Requires an existing `/usr/bin/quickshell` (>= v0.3.0) and skips Quickshell source compilation. | Fails if Quickshell is not found. |
| `--force-build-quickshell` | Forces building and installing the project's pinned Quickshell version from source. | Cannot be combined with `--skip-quickshell`. |
| `--clean-build-deps` | Automatically uninstalls build-only dependencies (compilers, `-dev` headers) post-build. | Only removes packages installed by this script; protects pre-existing tools. |
| `--keep-build-deps` | Retains build-only dependencies post-build without prompting. | Keeps them tracked for future uninstall. |
| `--remove-deps` | Used with `--uninstall` to automatically remove dependencies installed by Tide Island. | Never removes pre-existing tools (like `cmake` or `wl-clipboard`). |
| `--no-service` | Installs Tide Island without enabling or starting the `tide-island.service` user service. | Startup can be managed manually in compositor config. |
| `--uninstall` | Completely removes Tide Island binaries, libraries, caches, and build files. | Prompts for dependency cleanup; user config is strictly preserved. |
| `--dry-run` | Simulates actions and prints commands without making any changes to the system. | Safe for testing installation or uninstallation. |
| `--force` | Allows overriding package manager conflicts and overwrites existing files. | Use when replacing manual or AUR packages. |
| `-y`, `--yes` | Automatically confirms all interactive prompts (unattended mode). | Ideal for automated scripts and headless runs. |
| `-h`, `--help` | Displays command-line usage and option references. | Exits immediately. |

### Updating

To update, from your clone:

```bash
git pull
./install.sh
```

<br>

## Starting Tide Island

Tide Island provides a systemd user service.

Enable and start it immediately (Recommended):

```bash
systemctl --user enable --now tide-island.service
```

The service starts with `graphical-session.target`, so your session must start that target and pass
`WAYLAND_DISPLAY` to the systemd user manager. If it doesn't, or you want to manage startup
manually, start `tide-island` from your compositor's autostart instead.

<br>

## Configuration

Search `Tide Island Settings` in any application launcher, or run:

```bash
tide-island-config-app
```

- **Interaction**: Left, middle and right click actions for the clock area of the island (e.g. Control Center, Clipboard History, or None). The bell, battery and music sections always open the notification center, the battery popup and the player.
- **Weather**: Configure auto-detection or custom city name, temperature units (°C or °F), and refresh interval.
- **Calendar**: Quick month view with week numbers and relative date indicators. Click the date in the Control Center or use `quickshell ipc -p /usr/share/tide-island call tide toggleCalendar`; the scroll wheel / arrow keys browse months, `Home` returns to today and `Esc` closes.
- **Screen Recorder**:
  - While recording, the active recording card appears in the Control Center with a live timer.
- **System Tray (SNI)**:
  - A card in the Control Center with an item count pill badge and smooth horizontal wheel/touch scrolling.
  - Supports left-click activate, right-click context menus, wheel scrolling, and tooltip previews on hover.
- **Battery Health & Charge Limit (Conservation Mode)**:
  - Protect laptop battery longevity when connected to AC power. On supported hardware (such as Lenovo IdeaPads with `ideapad_acpi` or generic laptops supporting `charge_control_end_threshold`), toggle between **80% Conservation** mode and **100% Full Charge** directly in the dedicated Battery flyout panel.
  - Open the panel anytime by clicking the battery indicator pill in the Control Center header or the battery section of the resting island.
  - The installer automatically configures `/usr/lib/tmpfiles.d/tide-island-battery.conf`, enabling instantaneous, passwordless switching without root prompts.
- **Audio Device Switcher & Application Mixer**:
  - Click the `›` chevron on either the Sound or Microphone card in the Control Center to reveal the Audio flyout panel.
  - Instantly switch default output endpoints (Speakers, Headphones, HDMI, Bluetooth earbuds) and active microphone sources in real time.
  - Switch to the **Mixer** tab to adjust individual per-application volume sliders and toggle mute status, complete with freedesktop application icons.
- **Color Palette**: Tide Island reads its palette from `~/.config/tide-island/colors.json` (any generator can write it).
  - **Live Auto-Reload**: Palette updates on disk are automatically detected and reloaded instantly via `QFileSystemWatcher` without restarting the service.
  - **Transparency Preserved**: Island capsule background transparency (`islandBackgroundOpacity`) continues to work seamlessly alongside dynamic palette tints.
- **Commands** (`~/.config/tide-island/userconfig.json`, also in the settings app): split into words like a shell would, but never run through one: `'…'` and `"…"` quoting, backslash escapes, and a leading `~/` in any word for your home directory; no variables, globs or pipes (wrap those in a script).
  - `lockCommand`: the screen locker for the power menu's Lock (e.g. `gtklock -d`); empty tries gtklock, `loginctl lock-session`, then swaylock. Any failure is shown as a notice.
  - `idleInhibitCommand`: adds the caffeine button; it is run as `<command> toggle` and `<command> status` (which prints `on` or `off`).
- **Island edge**: `islandEdge` is `top` (default) or `bottom`.
- **Above fullscreen**: `islandAboveFullscreen` (default `false`) keeps the island on the overlay layer, so it stays visible over fullscreen windows ([if the compositor allows it](#compositor-support)).

Saving from the island (e.g. Do Not Disturb, the avatar) or the settings app rewrites
`userconfig.json` as plain JSON, so comments in it are not kept. When the file holds the TLP
sudo password it is written readable by you only.


## Common Commands

#### Restart after editing the configuration:

```bash
systemctl --user restart tide-island
```

#### Stop Tide Island:

```bash
systemctl --user stop tide-island
```

#### View logs:

```bash
journalctl --user -u tide-island -f
```

#### IPC Commands

Tide Island runs from `/usr/share/tide-island`, so IPC calls need `-p /usr/share/tide-island`.
`quickshell ipc -p /usr/share/tide-island show` lists every target and function.

| Command | Action |
| --- | --- |
| `quickshell ipc -p /usr/share/tide-island call tide togglePlayer` | Open or close music player |
| `quickshell ipc -p /usr/share/tide-island call tide toggleControlCenter` | Open or close control center |
| `quickshell ipc -p /usr/share/tide-island call tide togglePowerMenu` | Open or close power menu |
| `quickshell ipc -p /usr/share/tide-island call tide toggleFileShelf` | Open or close file shelf |
| `quickshell ipc -p /usr/share/tide-island call tide toggleCalendar` | Open or close calendar view |
| `quickshell ipc -p /usr/share/tide-island call tide openCalendar` | Open calendar view |
| `quickshell ipc -p /usr/share/tide-island call tide closeCalendar` | Close calendar view |
| `quickshell ipc -p /usr/share/tide-island call tide toggleWeather` | Open or close weather view |
| `quickshell ipc -p /usr/share/tide-island call tide openWeather` | Open weather view |
| `quickshell ipc -p /usr/share/tide-island call tide closeWeather` | Close weather view |
| `quickshell ipc -p /usr/share/tide-island call weather refresh` | Refresh weather data immediately |
| `quickshell ipc -p /usr/share/tide-island call tide toggleClipboard` | Open or close clipboard history |
| `quickshell ipc -p /usr/share/tide-island call tide openClipboard` | Open clipboard history |
| `quickshell ipc -p /usr/share/tide-island call tide closeClipboard` | Close clipboard history |
| `quickshell ipc -p /usr/share/tide-island call tide toggleNotificationCenter` | Open or close notification center |
| `quickshell ipc -p /usr/share/tide-island call tide toggleGlance` | Open or close the system glance |
| `quickshell ipc -p /usr/share/tide-island call tide showTimer` | Open the timer |
| `quickshell ipc -p /usr/share/tide-island call tide togglePrivacy` | Open or close Privacy & Media Activity HUD |
| `quickshell ipc -p /usr/share/tide-island call tide openPrivacy` | Open Privacy & Media Activity HUD |
| `quickshell ipc -p /usr/share/tide-island call tide closePrivacy` | Close Privacy & Media Activity HUD |
| `quickshell ipc -p /usr/share/tide-island call privacy toggle` | Open or close Privacy & Media Activity HUD |
| `quickshell ipc -p /usr/share/tide-island call privacy show` | Open Privacy & Media Activity HUD |
| `quickshell ipc -p /usr/share/tide-island call privacy close` | Close Privacy & Media Activity HUD |
| `quickshell ipc -p /usr/share/tide-island call island toggle` | Toggle dynamic island capsules |
| `quickshell ipc -p /usr/share/tide-island call island show` | Show dynamic island capsules |
| `quickshell ipc -p /usr/share/tide-island call island hide` | Hide dynamic island capsules |
| `quickshell ipc -p /usr/share/tide-island call recorder toggle` | Start or stop screen recording |
| `quickshell ipc -p /usr/share/tide-island call recorder start` | Start screen recording |
| `quickshell ipc -p /usr/share/tide-island call recorder stop` | Stop screen recording |
| `quickshell ipc -p /usr/share/tide-island call recorder toggleMic` | Toggle microphone audio capture |
| `quickshell ipc -p /usr/share/tide-island call recorder openRecordings` | Open recordings folder in file manager |
| `quickshell ipc -p /usr/share/tide-island call tide reloadColors` | Reload color palette from colors.json |
| `quickshell ipc -p /usr/share/tide-island call theme reload` | Reload color palette from colors.json |

<br>

## License

GNU General Public License v3.0, like both upstreams; see [LICENSE](LICENSE).

## Contributing

Issues, bug reports, design suggestions, and pull requests are all welcome.

-  only 1 topic per issue.
-  tell your ideas first before making a PR

## Acknowledgments

Heartfelt thanks and appreciation to:

- **[@enhaoswen](https://github.com/enhaoswen)**: The original creator and core architect of Tide Island, who built the remarkable foundation, animation engine, and vision for this Wayland dynamic island.
- **[@end-4](https://github.com/end-4)** for the workspace overview design inspiration
- **[@gozhuimeng](https://github.com/gozhuimeng)** for improving the lyrics backend
- **[@LatifKovani](https://github.com/LatifKovani)** for a significant improvement

---

<p align="center">
  <sub>
    A practical, beautiful, and highly customizable desktop experience for Wayland.
  </sub>
</p>
