# Audio Visualizer Widget Conversation Export

## Goal

Build a Kamidana `audio-visualizer` widget that captures live audio and displays a configurable status-bar visualizer.

Desired YAML configuration:

```yaml
- id: audio-visualizer
  type: audio-visualizer
  format: "~ {display} ~"
  gradient_separation: 1
  capture_scope: system
  channel_mode: stereo
  separation_length: 5
  smoothness: 0.5
  style:
    outline_color: ""
    gradient_color_1: "#f38ba8"
    gradient_color_2: "#a6e3a1"
    gradient_color_3: "#94e2d5"
    gradient_color_4: "#89dceb"
    gradient_color_5: "#89b4fa"
```

Expected behavior:

- `capture_scope`: `system | microphone`
- `channel_mode`: `stereo | mono`
- `separation_length`: number of bars, range `1...20`
- `gradient_separation`: number of gradient color groups, left/right max `2`, center max `5`
- `{display}` placeholder renders visualizer bars.

## Important Project Rule

The user explicitly requested that this be preserved permanently:

> 実行、テストはユーザーが行う

Meaning:

- The assistant must not run the app.
- The assistant must not run builds.
- The assistant must not run tests.
- The assistant must not run linters or diagnostics.
- The assistant should provide commands for the user to run instead.

This rule is also reflected in `Kamidana/AGENTS.md`.

## Implemented State

### Audio Capture

File:

- `Sources/KamidanaApp/module/AudioVisualizerController.swift`

Implemented:

- `AudioVisualizerController`
- `AudioVisualizerCaptureScope.system`
- `AudioVisualizerCaptureScope.microphone`
- `AudioVisualizerChannelMode.stereo`
- `AudioVisualizerChannelMode.mono`

System capture:

- Uses Core Audio Process Tap on macOS 14.2+.
- Uses `CATapDescription(stereoGlobalTapButExcludeProcesses:)` for stereo.
- Uses `CATapDescription(monoGlobalTapButExcludeProcesses:)` for mono.
- Creates a private Aggregate Device.
- Uses IOProc and a ring buffer.

Microphone capture:

- Uses `AVAudioEngine`.
- Requires `NSMicrophoneUsageDescription`.

Notes:

- High-frequency debug `print` calls were removed.
- Current visualizer values are time-domain RMS buckets, not FFT frequency bands.

### Widget

File:

- `Sources/KamidanaApp/UI/Widgets/AudioVisualizerWidget.swift`

Implemented config type:

- `AudioVisualizerWidgetConfig`

Current config fields:

- `format`
- `gradientSeparation`
- `captureScope`
- `channelMode`
- `smoothness`
- `outlineColor`
- `gradientColors`
- `separationLength`

Resolved bar count:

```swift
public var resolvedBarCount: Int {
    min(20, max(1, separationLength))
}
```

`AudioVisualizerWidgetModel` behavior:

- Holds `barCount` fixed at init time from `config.resolvedBarCount`.
- Initializes `levels` in `init`.
- Calls:

```swift
Self.normalizedLevels(
    from: buffer,
    channelMode: self.config.channelMode,
    barCount: self.barCount
)
```

Important design point:

- `normalizedLevels` is `static` and receives `barCount`.
- It must not access instance property `config`.

Audio channel behavior:

- `mono` mode downmixes available left/right channels before RMS.
- `stereo` mode computes across available channels.

Display characters:

```swift
▁▂▃▄▅▆▇█
```

Color logic:

- `separation_length` = number of bars.
- `gradient_separation` = number of color groups used.
- Color index:

```swift
let colorIndex = min(
    colorCount - 1,
    index * colorCount / config.resolvedBarCount
)
```

### Widget Registry

File:

- `Sources/KamidanaApp/UI/Widgets/WidgetRegistry.swift`

Registered widget:

```swift
GenericWidgetFactory<AudioVisualizerWidgetConfig, AudioVisualizerWidget>(
    typeID: "audioVisualizer",
    viewMaker: { config in AudioVisualizerWidget(config: config) },
    tabNameMaker: { _ in "Audio Visualizer" }
)
```

### Configuration Schema

File:

- `Sources/KamidanaApp/config/KamidanaConfigurationV1.swift`

Added enums:

```swift
public enum KamidanaAudioVisualizerCaptureScope: String, Codable, Equatable, Hashable {
    case system
    case microphone
}

public enum KamidanaAudioVisualizerChannelMode: String, Codable, Equatable, Hashable {
    case stereo
    case mono
}
```

Added widget kind:

```swift
case audioVisualizer = "audio-visualizer"
```

Added widget fields:

- `gradientSeparation`
- `captureScope`
- `channelMode`
- `separationLength`
- `smoothness`

Added style fields:

- `outlineColor`
- `gradientColor1`
- `gradientColor2`
- `gradientColor3`
- `gradientColor4`
- `gradientColor5`

Added coding keys:

- `gradient_separation`
- `capture_scope`
- `channel_mode`
- `separation_length`
- `smoothness`
- `outline_color`
- `gradient_color_1`
- `gradient_color_2`
- `gradient_color_3`
- `gradient_color_4`
- `gradient_color_5`

Defaults:

- `gradient_separation`: `1`
- `capture_scope`: `.system`
- `channel_mode`: `.stereo`
- `separation_length`: `5`
- `smoothness`: `0.5`

Validation:

- `gradient_separation`: left/right `1...2`, center `1...5`
- `separation_length`: `1...20`
- `smoothness`: `0...1`
- `format` and `compact_format`, if present, must contain exactly one `{display}`.
- Audio visualizer-specific fields are valid only for `audio-visualizer`.

### Adapter

File:

- `Sources/KamidanaApp/config/KamidanaConfigurationV1Adapter.swift`

Added `.audioVisualizer` mapping to runtime config:

```swift
WidgetInstance(
    typeID: "audioVisualizer",
    config: AudioVisualizerWidgetConfig(
        format: format,
        gradientSeparation: widget.gradientSeparation ?? 1,
        captureScope: widget.captureScope ?? .system,
        channelMode: widget.channelMode ?? .stereo,
        smoothness: widget.smoothness ?? 0.5,
        outlineColor: style.outlineColor,
        gradientColors: gradientColors,
        separationLength: widget.separationLength ?? 5
    ),
    ...
)
```

`mergedStyle` carries the new style fields.

### Info.plist

File:

- `Resources/Info.plist`

Added:

- `NSAudioCaptureUsageDescription`
- `NSMicrophoneUsageDescription`

### Documentation

File:

- `document/Audio.md`

Added documentation for:

- Final YAML schema
- `{display}`
- `gradient_separation`
- `capture_scope`
- `channel_mode`
- `separation_length`
- `smoothness`
- `outline_color`

### Tests Added or Updated

Files:

- `Tests/KamidanaTests/Audio/AudioVisualizerControllerTests.swift`
- `Tests/KamidanaTests/AudioVisualizerWidgetTests.swift`
- `Tests/KamidanaTests/KamidanaConfigurationV1Tests.swift`
- `Tests/KamidanaTests/KamidanaConfigurationV1AdapterTests.swift`

Per project rule, the assistant did not run these tests.

## Reported Issue

The user reported:

> 実行したんだけどエラーがなしで、何も表示されない、原因を調査して。さっきまでは問題なく動いた

Investigation was started but interrupted.

A terminal attempt to inspect `~/.config/kamidana/config.yaml` was denied by user/tool policy, so the actual runtime config still needs to be checked by the user or pasted into the conversation.

## Possible Causes for Widget Not Appearing

Potential config placement issues:

- The widget may be in a profile that is not active for the current display.
  - Example: widget is under `external`, but the active display is `built_in`.
  - Or the reverse.
- The project may be using combined monitor-profile YAML with top-level `external` and `built_in`.
- The widget may be in the wrong section/profile.

Potential center widget issues:

- If the widget is placed in `center`, it may not be visible unless selected or configured as default.
- Check `center_default` if the compact island UI is being used.

Potential format issues:

- `format` must use `{display}`.
- Old placeholder `{visualizer}` is invalid.
- Validation now rejects formats without exactly one `{display}`.

Potential field-name issues:

- YAML must use `separation_length`, not `separationLength`.
- `separation_length` must be in range `1...20`.

Potential channel mode issues:

- Old values `left` and `right` were removed.
- Valid values are now only:
  - `stereo`
  - `mono`

Potential audio capture issues:

- If the widget shell appears but bars remain flat, capture may be failing.
- `system` capture requires macOS 14.2+ and audio capture permission.
- `microphone` capture requires microphone permission and default input availability.

Important distinction:

- Capture failure should make bars flat, but the widget shell should still render.
- If nothing appears at all, config placement or widget registration is more likely than audio capture.

## Previous Error Explanation

User encountered:

```text
Instance member 'config' cannot be used on type 'AudioVisualizerWidgetModel'
Extra arguments at positions #3, #4 in call
```

Cause:

- `self.config` was used inside a `static` method.
- Static methods belong to the type, not an instance, so they cannot access instance properties.
- The call also passed labels/arguments that did not match the function signature.

Correct pattern:

```swift
let newLevels = Self.normalizedLevels(
    from: buffer,
    channelMode: self.config.channelMode,
    barCount: self.barCount
)
```

And:

```swift
static func normalizedLevels(
    from buffer: AudioVisualizerPCMBuffer,
    channelMode: KamidanaAudioVisualizerChannelMode,
    barCount: Int
) -> [Double] {
    ...
}
```

Important:

- Static function receives `barCount` explicitly.
- Static function does not access `self.config`.

## Broken Code Fragment That Was Fixed

A broken fragment existed inside the mono branch:

```swift
) -> [Double] {
```

This was removed by rewriting the file.

## Variable Management Fix

Problematic pattern:

```swift
@Published private(set) var levels: [Double] = Array(
    repeating: 0,
    count: AudioVisualizerWidgetConfig().separationLength
)
```

This used a default config value and then overwrote `levels` in `init`.

Preferred pattern:

```swift
@Published private(set) var levels: [Double]
```

Then initialize from the injected config:

```swift
self.barCount = config.resolvedBarCount
self.levels = Array(repeating: 0, count: barCount)
```

## Test Commands for User to Run

Focused tests:

```sh
swift test --filter AudioVisualizerWidgetTests
swift test --filter KamidanaConfigurationV1Tests
swift test --filter KamidanaConfigurationV1AdapterTests
swift test --filter AudioVisualizerControllerTests
```

Run app:

```sh
make run
```

Debug packaged app:

```sh
make debug
```

## Recommended Next Investigation Steps

1. Check actual `~/.config/kamidana/config.yaml` placement.
2. Confirm whether the active display profile is `external` or `built_in`.
3. Confirm the widget is in a visible layout section.
4. If placed in `center`, check `center_default`.
5. Confirm `type: audio-visualizer`.
6. Confirm `format` contains exactly one `{display}`.
7. Confirm `channel_mode` is `stereo` or `mono`.
8. Confirm `separation_length` exists and is in `1...20`.
9. If widget appears but bars are flat, check macOS permissions and capture scope.

## Potential Future Work

- Replace RMS time buckets with true FFT frequency bands.
- Add shared audio capture service so multiple visualizers do not create multiple tap pipelines.
- Add visible UI states for:
  - permission denied
  - unavailable
  - no audio
  - recovering
- Add output-device change recovery.
- Improve thread-safety in capture state transitions.
