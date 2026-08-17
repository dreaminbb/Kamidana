# Logging (Rich Console / Debug)

Rich console outputs in Kamidana are centralized in `DebugRichConsole`.  
This tool is intended exclusively for debugging (enabled by default only in `DEBUG` builds).

## Usage

Call it from any file as shown below:

```swift
DebugRichConsole.printSystemMatrix(newData)
```

## Toggling Enabled/Disabled

Output is controlled via `DebugRichConsole.isEnabled`.

```swift
DebugRichConsole.isEnabled = true   // Enable output
DebugRichConsole.isEnabled = false  // Disable output
```

## Guidelines for Additions

When adding new log outputs, implement them in `DebugRichConsole` rather than scattering `print(...)` statements across the codebase.  
For byte formatting, use the shared `DebugRichConsole.formatBytes(_:)` method.
