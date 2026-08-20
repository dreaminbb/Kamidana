Main Config folder path should be `$HOME/.config/kamidana`

## Monitor-specific Configuration Files

Kamidana reads independent configuration files for regular and built-in displays:

- `~/.config/kamidana/config.yaml`: external and other regular displays
- `~/.config/kamidana/built_in_monitor.yaml`: the built-in display

Both files use the same top-level schema: `global`, `left`, `center`, and `right`. This allows each display type to define its own global style without nesting it under a monitor key.

```yaml
global:
  background_mode: per_widget
  style:
    corner_radius: 0

left:
  widgets: []

center:
  center_default: clock
  widgets:
    - id: clock
      type: clock
      compact_format: "{time}"

right:
  widgets: []
```

The application selects the file automatically by checking whether the active main display is built in. If `built_in_monitor.yaml` does not exist, `config.yaml` is used for both display types. If only `built_in_monitor.yaml` exists, it is used as the fallback for regular displays as well. Widget IDs must be unique within each file, but the same IDs may be reused across the two files.

## NerdFont Icons Configuration

NerdFont icons are no longer configured via `nerdfont.toml`. Instead, they are defined directly as default `String` values in `configManager.swift` within the widget configurations, making them easily overridable via the main `config.yaml` file.

### Default Icon Reference

| Key | Icon | Key | Icon |
|-----|------|-----|------|
| `bluetooth` | `󰂯` | `bluetoothSlash` | `󰂲` |
| `wifi` | `󰤨` | `wifiSlash` | `󰤭` |
| `network` | `󰲝` | `battery` | `󰁹` |
| `batteryEmpty` | `󰂃` | `batteryQuarter` | `󰁺` |
| `batteryHalf` | `󰁾` | `batteryThreeQuarters` | `󰂁` |
| `batteryCharging` | `󰂄` | `cpu` | `󰍛` |
| `memory` | `󰘚` | `gpu` | `󰢮` |
| `disk` | `󰋊` | `arrowUpRight` | `󰁝` |
| `arrowDownRight` | `󰁅` | `arrowUpCircle` | `󰁝` |
| `arrowDownCircle` | `󰁅` | `clock` | `󰥔` |
| `music` | `󰝚` | `play` | `󰐊` |
| `pause` | `󰏤` | `forward` | `󰒭` |
| `backward` | `󰒮` | `speaker` | `󰕮` |
| `speakerWave` | `󰕾` | `mic` | `󰍬` |
| `micSlash` | `󰍭` | `appleLogo` | `󰀵` |
| `paperplane` | `󰈆` | `thermometer` | `󰔏` |
| `link` | `󰌹` | `linkPlus` | `󰌺` |
| `arrowClockwise` | `󰑐` | `bolt` | `󰌪` |
| `grid` | `󰕰` | `list` | `󰝖` |
| `bed` | `󰒲` | `laptop` | `󰌢` |
| `power` | `⏻` | `exit` | `󰈆` |
| `lock` | `󰌾` | | |

You can override any of these icons in your `config.yaml` by specifying the character string directly in the respective widget's configuration.

## Widget Format Placeholders

The regular v1 configuration file is located at `~/.config/kamidana/config.yaml`, and the built-in display configuration is located at `~/.config/kamidana/built_in_monitor.yaml`. Regular widgets use the `format` property to control their compact text. Nerd Font glyphs written directly in a format are rendered with `style.icon_color`; text and placeholder values use `style.color`.

### Music Widget

The Music widget supports text placeholders and two SwiftUI component placeholders. Component placeholders select predefined application UI; they do not allow arbitrary positioning.

| Placeholder | Value |
|---|---|
| `{artwork}` | Circular album artwork, or the configured fallback music icon |
| `{slider}` | Previous, play/pause, next, and playback-position controls |
| `{title}` | Current track title, or `Not Playing` |
| `{artist}` | Current artist |
| `{album}` | Current album |
| `{icon}` | Default music Nerd Font icon |

For a Music widget in `left` or `right`, define the normal and activated formats directly on the widget. `extend` controls the visual expansion direction. When omitted, it defaults to `right` in the left section and `left` in the right section.

```yaml
- id: music-left
  type: music
  activate: hover
  format: "{artwork} {title}"
  format_on_action: "{artwork} {slider}"
  slider_change: "#cdd6f4"
  slider_pause: "#a6e3a1"
  slider_bar: "#89b4fa"
  extend: right
  artwork_spin: 3
```

For the center Music widget, `normal` defines the collapsed Island and its playback controls. `on_action` defines the metadata row shown while the Island is expanded. A center-default Music widget may use `normal.format` instead of `compact_format`.

```yaml
- id: music
  type: music
  normal:
    format: "{artwork} {title}"
    format_on_action: "{artwork} {slider}"
    slider_change: "#cdd6f4"
    slider_pause: "#a6e3a1"
    slider_bar: "#89b4fa"
    extend: right
    artwork_spin: 3
  on_action:
    format: "{title} - {album}"
    artwork_spin: 3
```

The color keys have fixed roles: `slider_change` styles previous/next controls, `slider_pause` styles play/pause, and `slider_bar` styles the seek bar. `artwork_spin` is the number of seconds per rotation while playback is active. Set it to `0` to disable rotation; negative values are invalid.

### Memory Widget

The Memory widget provides these placeholders:

| Placeholder | Value |
|---|---|
| `{used_gb}` | Currently used memory in GiB, with one decimal place |
| `{total_gb}` | Physical memory capacity in GiB, with one decimal place |
| `{usage}` | Memory use as a percentage, with one decimal place |

Examples:

```yaml
- id: memory
  type: memory
  format: " {used_gb} / {total_gb} GB"

- id: memory-percent
  type: memory
  format: " {usage}%"
```

### Bluetooth Widget

The Bluetooth widget provides these placeholders:

| Placeholder | Value |
|---|---|
| `{icon}` | Connected or disconnected Bluetooth icon |
| `{status}` | Bluetooth power state: `on` or `off` |
| `{device}` | Number of currently connected devices |
| `{device_name}` | Name of one currently connected device; empty when none are connected |
| `{device_count}` | Number of paired devices, retained for compatibility |

Example:

```yaml
- id: bluetooth
  type: bluetooth
  format: "{icon} {device} {device_name}"
```
