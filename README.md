# Kamidana

A customizable, native status bar for macOS — built with Swift and SwiftUI.

Inspired by [YASB (Yet Another Status Bar)](https://github.com/amnweb/yasb) on Windows, Kamidana brings the same philosophy to macOS: a beautiful, information-dense top bar that feels native and stays out of your way.

---

## Features

### System Monitor

| Widget | Details |
|---|---|
| **CPU** | Overall & per-core usage graph, clock speed, top processes |
| **Memory** | App / Wired / Compressed / Free breakdown, top processes |
| **GPU** | Real-time GPU usage |
| **Disk** | Usage graph, free space, I/O speed (R/W MB/s), top processes |
| **Network** | Live upload / download speed (Mbps) |
| **Battery** | Level (%), charging status, wattage (W), remaining time |
| **Thermal** | System thermal state |


### Kamidana Island
- Expandable island UI for music playback — artwork, controls, and seek bar in one place
- Adapts between compact (built-in display) and full (external display) modes

### Design
- Glassmorphism-style modules with hover effects
- Nerd Font icon system via external TOML config
- Multi-monitor aware — auto-repositions on wake and display changes

---

## Getting Started

### Requirements
- macOS 14 (Sonoma) or later
- Swift 6.0+
- [Nerd Font](https://www.nerdfonts.com/) installed

### Build & Run

```bash
# Development (debug)
make run

# Build .app bundle
make app

# Debug mode with terminal logging
make debug
```

### Project Structure

```
Sources/Kamidana/
  UI/Widgets/       # All widget views (CPU, Memory, Music, etc.)
  module/           # Backend managers (Bluetooth, Music, Network)
  Audio/            # Audio device management
Theme/              # Color theme definitions
nerdfont.toml       # Icon character mappings
```

---

## Roadmap

### In Progress
- [ ] Calendar widget
- [ ] Weather widget (API-based)
- [ ] CAVA audio visualizer
- [ ] Collapsible widget groups

### Planned
- [ ] Caffeinate toggle (prevent sleep)
- [ ] Force quit current app
- [ ] Notification display
- [ ] Fullscreen show / hide option
- [ ] Launch at login
- [ ] Multi-monitor display selection
- [ ] Settings app with GUI
- [ ] Theme file format (JSON / YAML / Lua)
- [ ] Auto-update via Sparkle
- [ ] Project website

### Ideas
- [ ] Unified theme management (Ghostty, Tmux, Starship, wallpaper)
- [ ] Timer widget

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct, development setup, and pull request process.

1. Check the [Issues](../../issues) and [Project Board](https://github.com/users/dreaminbb/projects/11) for tasks tagged `good first issue` or `help wanted`
2. Fork the repo and create a feature branch
3. Submit a Pull Request

---

## License
MIT License

---

## Acknowledgements

- [YASB](https://github.com/amnweb/yasb) — The Windows status bar that inspired this project
- [Nerd Fonts](https://www.nerdfonts.com/) — Icon font
