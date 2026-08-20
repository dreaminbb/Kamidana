# Compact UI

Compact display for built-in displays is managed by `UISettingsStore`.

## Configuration Variables

- `displayModePolicy`
  - `.auto`: compact only when built-in display is detected
  - `.alwaysCompact`: always compact
  - `.alwaysRegular`: always regular display
- `collapsedWidgets`
  - Set of widgets to collapse in compact mode
  - Default value: `disk`, `gpu`

## Storage Location

Persisted in the following keys in `UserDefaults`:

- `ui.displayModePolicy`
- `ui.collapsedWidgets`

## Detection Logic

- `DisplayDetector.isBuiltInMainDisplay()`
  - Retrieve `NSScreenNumber` from `NSScreen.main`
  - Determine built-in display status using `CGDisplayIsBuiltin`

## UI Behavior

- Use the `built_in` profile from `config.yaml` when the active main display is built in
- Use the `external` profile from `config.yaml` for an external or other regular main display
- Reduce font size and spacing when compact mode is active
- On the right side, **only CPU / Memory are always displayed**
- Others (Network / GPU / Disk / Battery / Clock) are collapsed under the `list.bullet` icon
- Audio codec is not always displayed; it is shown only inside the popover
- The compact center Music Island is pinned to the screen center so it aligns with the built-in camera/notch
- Hovering the center Music Island expands it downward from that centered position
