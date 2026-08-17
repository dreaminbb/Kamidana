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

- Reduce font size and spacing when compact mode is active
- On the right side, **only CPU / Memory are always displayed**
- Others (Network / GPU / Disk / Battery / Clock) are collapsed under the `list.bullet` icon
- Audio codec is not always displayed; it is shown only inside the popover
- Music is placed in the left group and displayed to the left of Wi-Fi
