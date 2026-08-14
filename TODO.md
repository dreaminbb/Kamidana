## App Features

### Bug Fixes

### System Monitor

#### CPU
- [x] Usage graph (* Percentage-based overall/per-core display implemented)
- [x] Per-core usage rate
- [x] Clock speed
- [x] Top processes by usage (implemented with icon retrieval)

#### Memory
- [x] Retrieve and display App, Wired, Compressed, and Free memory amounts (* Overall used memory calculation implemented)
- [x] Top processes by usage (implemented with icon retrieval)

#### Disk
- [x] Usage graph
- [x] Free space
- [x] Top processes by usage (implemented with icon retrieval)
- [x] Disk I/O speed (Read/Write MB/s)

#### Network
- [x] Real-time display of network speed (Up/Down Mbps)

#### Battery & Power
- [x] Battery level (%) display
- [x] Charging status (AC / Battery) and remaining time display
- [x] Power consumption / charging wattage (W) retrieval

#### GPU & Hardware Sensors
- [x] GPU usage retrieval and display
- [x] Mac temperature (thermal status) retrieval and display

### Utilities & OS Operations

#### Networking (Wi-Fi / Bluetooth)
- [x] Wi-Fi connection and switching
    - [x] Local IP display
    - [x] Nearby Wi-Fi list display (popover UI implemented)
    - [x] New connection feature (CoreWLAN password connection implemented)
    - [x] Connect / disconnect feature

#### Media & Audio
- [x] Display playing track info (Apple Music, Spotify, etc.)
- [x] Play / pause / skip controls
- [x] Speaker volume / microphone input level display and mute toggle
- [x] Change audio input / output

#### Daily Tools
- [ ] Clock / Calendar display (* Current time display implemented)
- [ ] Caffeinate feature (prevent Mac from sleeping when enabled)

#### System
- [x] Sleep, restart, shutdown, logout
- [ ] Setting to show or hide in fullscreen
- [x] About This Mac
- [ ] Force quit current app

### Notifications
- [ ] Enable displaying notifications received by user
- [ ] Show information when UI is clicked

### Weather
- [ ] Fetch weather information from API provider
- [ ] Allow on-the-fly change of displayed location's weather by input

### OS Integration & Core System
- [ ] Auto-adjust UI when using MacBook built-in monitor
- [ ] Choose which monitor to display on
- [ ] Launch at login option
- [ ] Permission request UI (Accessibility/Root permission acquisition flow required for process info and OS control)
- [x] Fix rendering position shift upon waking from sleep or changing monitors (fix UI as persistent bar)

### Settings & Architecture
- [ ] Create a simple app to modify settings
- [ ] Download button for [#Server] templates
- [ ] Settings for displayed UI
- [ ] Define theme file format (specifications for customization such as JSON/YAML/Lua)
- [ ] App auto-update feature (introduce Sparkle, etc.)

### Ideas
- [ ] Create timer
- [ ] Manage themes for apps like Ghostty, Tmux, Starship in batch + change wallpaper

## Website
- [ ] Build it!

## Fixes
- [ ] Display local IP, DNS, and packet loss in network speed UI
- [ ] Cache artwork of previously played songs, fetch from cache for newly played songs
- [ ] Show / hide in fullscreen mode

## Additions
- [ ] Is it possible to add a complete Bluetooth manager at the app level?

## Essential
- [ ] Calendar
- [ ] CAVA UI
- [ ] Weather
- [ ] Make system display UI collapsible; collapse only specified icons

- [ ] IP display
- [ ] Settings management
