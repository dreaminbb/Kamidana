Main Config folder path should be `$HOME/.config/kamidana`

## Monitor Profiles

Kamidana reads both display profiles from `~/.config/kamidana/config.yaml`. The top-level `external` and `built_in` keys each contain a complete `global`, `left`, `center`, and `right` configuration.

```yaml
external:
  global:
    background_mode: per_widget
    bar_padding: 0
  left:
    widgets: []
  center:
    center_default: external-clock
    widgets:
      - id: external-clock
        type: clock
        compact_format: "{time}"
  right:
    widgets: []

built_in:
  global:
    background_mode: per_widget
    bar_padding: 0
  left:
    widgets: []
  center:
    center_default: built-in-clock
    widgets:
      - id: built-in-clock
        type: clock
        compact_format: "{time}"
  right:
    widgets: []
```

The application selects the profile automatically by checking whether the active main display is built in. Both profiles are required. Widget IDs must be unique inside each profile, but the same IDs may be reused between `external` and `built_in`.

The previous two-file layout remains readable for migration, but new configuration and documentation use only the combined file.

## Widget and Popup Surfaces

`style` controls the normal widget surface. `popup_style` controls its expanded panel. Both accept `background`, `color`, `opacity`, `corner_radius`, `material`, `border`, and `shadow`. `style` additionally controls the compact widget's padding and hover state.

`popup_style` may be declared under `global`, a section (`left`, `center`, or `right`), or an individual widget. Values inherit in that order, so a widget only needs to override the fields that differ. Popup positioning remains application-defined: panels have no speech-bubble arrow and are aligned inward automatically for the left and right sections.

`bar_padding` belongs to `global` and controls the gap between the bar window and the monitor edges. It accepts either a single number or an object with `top`, `bottom`, `leading`, and `trailing`. `top` moves the whole window down from the top edge, `leading` and `trailing` inset the window horizontally, and `bottom` reduces the available vertical extent. When `top` is `0`, the top border is hidden; when `trailing` is `0`, the side borders are hidden.

```yaml
global:
  bar_padding:
    top: 0
    leading: 0
    trailing: 0
  style:
    corner_radius: 8
    border:
      width: 1
      color: "#585b70"
  popup_style:
    background: "#1e1e2e"
    opacity: 0.96
    corner_radius: 12
    material: ultra_thin
    border:
      width: 1
      color: "#585b70"

left:
  widgets:
    - id: system-actions
      type: system-action
      icon: "󰀵"
      popup_style:
        corner_radius: 16
        border:
          width: 2
          color: "#89b4fa"
      children:
        - id: sleep
          type: sleep
          format: "Sleep"
          icon: "󰒲"
```

Set `border.width` to `0` to disable an outline. The same distinction applies to center: `style` is the collapsed Island surface and `popup_style` is its expanded surface.

## Widget Motion

Every widget accepts `motion`. It controls application-owned expansion and popup transitions without allowing arbitrary UI positioning.

| Value | Behavior |
|---|---|
| `dynamic` | Animate expansion and popup state changes. This is the default. |
| `static` | Present and dismiss immediately without animation. |

```yaml
- id: system-actions
  type: system-action
  motion: static
  icon: "󰀵"
  children:
    - id: sleep
      type: sleep
      format: "Sleep"
      icon: "󰒲"
```

The same setting controls a center-default widget's Island expansion. Each monitor configuration may choose a different value. All popup types use the same motion path; `static` never runs a presentation transition.

`style.animation` remains responsible for surface styling transitions such as hover colors; `motion` controls whether popup and expansion movement occurs. For `activate: hover`, the popup remains open while either the normal widget or the popup itself is hovered, including while the pointer crosses the gap between them.

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

The v1 configuration file is located at `~/.config/kamidana/config.yaml`. Widgets inside either monitor profile use the `format` property to control their compact text. Nerd Font glyphs written directly in a format are rendered with `style.icon_color`; text and placeholder values use `style.color`.

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

### Volume Widget

The compact bar does not display codec information automatically. Hovering the widget (or clicking it when `activate: click`) opens one predefined panel containing both enabled Output and Input sections. Each section contains its codec, volume, mute control, current device, and device list.

| Placeholder | Value |
|---|---|
| `{icon}` | Primary output icon, or input icon when output management is disabled |
| `{volume}` | Primary output volume, or input volume when output management is disabled |
| `{output_icon}` | Output mute or active icon |
| `{output_volume}` | Output volume percentage without `%` |
| `{output_device}` | Current output device name |
| `{input_icon}` | Input mute or active icon |
| `{input_volume}` | Input volume percentage without `%` |
| `{input_device}` | Current input device name |

```yaml
- id: volume
  type: volume
  activate: hover
  motion: dynamic
  format: "{output_icon} {output_volume}% {input_icon} {input_volume}%"
  output_management: true
  input_management: true
```

### Network Widget

| Placeholder | Value |
|---|---|
| `{connection_icon}` | Wired, Wi-Fi, or offline icon |
| `{ssid}` | Current SSID for Wi-Fi; empty for wired and offline connections |
| `{network_name}` | SSID for Wi-Fi, interface-qualified Ethernet name for wired, or connection fallback |
| `{upload}` | Current upload rate |
| `{upload_icon}` | Upload icon |
| `{download}` | Current download rate |
| `{download_icon}` | Download icon |

The Wi-Fi panel reports scanning, empty, permission-denied, and scan-failure states separately. Active scans run off the UI thread, and cached CoreWLAN results are used when a refresh cannot produce a new list. Wi-Fi scans remain disabled while wired Ethernet is active.

```yaml
- id: network
  type: network
  format: "{connection_icon} {network_name} {upload_icon} {upload}/s {download_icon} {download}/s"
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
