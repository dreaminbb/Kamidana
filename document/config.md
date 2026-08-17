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
