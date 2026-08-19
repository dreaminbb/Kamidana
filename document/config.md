Main Config folder path should be `$HOME/.config/kamidana`

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

The v1 configuration file is located at `~/.config/kamidana/config.yaml`. Regular widgets use the `format` property to control their compact text. Nerd Font glyphs written directly in a format are rendered with `style.icon_color`; text and placeholder values use `style.color`.

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
