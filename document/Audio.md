# Audio Visualizer

The audio visualizer displays frequency data from macOS audio output. It is a
separate audio-analysis capability, not a part of the music metadata service.

## Decision

Implement the visualizer as an independent, configuration-driven widget.

The visualizer may later be displayed alongside the Music widget or inside a
Music Island view, but its capture and analysis lifecycle must not depend on
`MusicPlayingManager`. System audio can come from a browser, a game, a video
call, or another application when no supported music player is active.

## macOS Audio Capture

### Core Audio Process Tap (primary path)

macOS 14.2 and later provides public Core Audio APIs for capturing output audio
without installing a virtual audio driver:

- `CATapDescription` describes the target processes and mixdown behavior.
- `AudioHardwareCreateProcessTap` creates the tap.
- `AudioHardwareCreateAggregateDevice` exposes the tap as a private input
  stream for the creating application.
- `AudioDeviceCreateIOProcID` and `AudioDeviceStart` deliver PCM buffers to the
  analysis pipeline.

The recommended system-wide configuration is a private stereo global tap with
unmuted output. A mono global tap may be provided as an option when the
visualizer only needs one channel. The private aggregate device must be
destroyed when capture stops or fails.

This is not the same as installing a user-visible virtual audio device. The
aggregate device is created at runtime for the visualizer and is owned by the
application.

Apple references:

- [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- [AudioHardwareCreateProcessTap](https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap%28_%3A_%3A%29)

### ScreenCaptureKit (compatibility path)

macOS 13 and later provides system audio capture through ScreenCaptureKit.
Set `SCStreamConfiguration.capturesAudio` to `true` and consume audio sample
buffers from an `SCStream` output. This path is useful when supporting macOS
13.x or when the application already has a screen-capture session.

ScreenCaptureKit is not the preferred audio-only implementation because it is
based on a display, window, or application capture session and requires screen
and system-audio recording permission.

Apple references:

- [SCStreamConfiguration.capturesAudio](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio)
- [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)

### Older macOS versions

Before macOS 14.2, public Core Audio APIs do not expose the system output mix
as a normal input stream. Supporting those versions requires ScreenCaptureKit
on macOS 13 or a user-installed loopback device such as BlackHole or
Soundflower. The visualizer must not silently assume that the default output
device can be opened for input.

## Permission and Failure Handling

System audio capture requires explicit user consent. The application must
provide a clear usage description, handle denial without crashing, and show a
recoverable disabled state in the widget.

For Core Audio Tap builds, include an appropriate `NSAudioCaptureUsageDescription`
entry in the application `Info.plist`. ScreenCaptureKit uses the screen and
system-audio recording permission managed by macOS.

Permission, device, and stream errors must be routed through the project's
`DebugRichConsole`; do not print from the real-time audio callback or from
polling loops. The UI must distinguish at least these states:

- unavailable on the current macOS version
- permission required or denied
- no output audio available
- capturing and analyzing
- stopped or recovering after an output-device change

## Analysis Pipeline

The capture layer must remain independent from SwiftUI and must not perform
FFT or other expensive work on the Core Audio real-time callback.

```text
Core Audio Tap / ScreenCaptureKit
        -> bounded audio buffer
        -> analysis queue
        -> windowing and FFT
        -> smoothing / peak hold
        -> main-actor published visualizer state
        -> widget rendering
```

Requirements:

- Keep the callback allocation-free and short.
- Use a bounded buffer so a slow UI cannot grow memory without limit.
- Resample or normalize formats at the analysis boundary when necessary.
- Publish reduced visual data, not raw PCM, to SwiftUI.
- Use monospaced or fixed-width visual elements where changing values could
  cause status-bar jitter.
- Stop and recreate the capture pipeline when the output device or stream
  format changes.
- Keep the analysis update rate independent from the metadata polling interval
  used by `MusicPlayingManager`.

The first implementation should use a fixed application-defined band count,
for example 8, 16, or 32 bands. Configuration may select a supported preset,
but must not expose arbitrary view coordinates or internal layout constraints.

## Widget Architecture

The backend should be a dedicated observable manager, for example an audio
capture/analysis manager in `Sources/KamidanaApp/module/` or `Audio/`. It owns
permission state, capture lifecycle, buffering, FFT processing, and recovery.

The widget owns only presentation and user actions such as starting, stopping,
or opening the relevant System Settings pane. It receives shared state through
the environment and uses the active `Theme`, `SmoothUIModule(theme:)`, and the
shared widget interaction foundation.

The widget must be added through the normal configuration flow:

1. Add a validated `KamidanaWidgetKind` case.
2. Add decoding and type-specific validation.
3. Map it in `KamidanaConfigurationV1Adapter`.
4. Register its factory in `WidgetRegistry`.
5. Add deterministic manager and rendering-model tests.
6. Update `Example/config.yaml` when the example should show it.

### Audio Visualizer Configuration

```yaml
- id: audio-visualizer
  type: audio-visualizer
  format: "~ {display} ~"
  gradient_separation: 1
  capture_scope: system
  channel_mode: stereo
  smoothness: 0.5
  style:
    outline_color: ""
    gradient_color_1: "#f38ba8"
    gradient_color_2: "#a6e3a1"
    gradient_color_3: "#94e2d5"
    gradient_color_4: "#89dceb"
    gradient_color_5: "#89b4fa"
```

- `format` uses `{display}` for the fixed five-bar visualizer output.
- `gradient_separation` selects how many configured gradient colors are used. It accepts
  `1...2` in left and right sections and `1...5` in the center section.
- `capture_scope` accepts `system` or `microphone`. System capture requires macOS 14.2 or
  later; microphone capture uses the current default input device.
- `channel_mode` accepts `stereo` or `mono`. Mono mode downmixes the available left and
  right channels before level analysis.
- `smoothness` accepts values in `0...1`.
- An empty `outline_color` disables the outline.

## Music Widget Relationship

The visualizer should not be implemented as a field or polling branch in
`MusicPlayingManager` or `MusicWidget`.

Reasons:

- System audio is broader than Spotify or Apple Music playback.
- Audio capture has different permissions and failure modes from AppleScript
  metadata access.
- FFT data updates frequently, while music metadata is intentionally polled at
  a much lower interval.
- A standalone widget can be placed in left, center, or right layouts and can
  be hidden without changing Music widget behavior.
- Independent ownership makes future ScreenCaptureKit fallback support and
  output-device recovery easier to test.

An optional Music Island presentation can consume the same published analysis
state later. That should be a presentation adapter, not a second capture
pipeline.

## Recommended Rollout

1. Implement and test the Core Audio Tap capture manager for macOS 14.2+.
2. Add FFT, smoothing, and a deterministic band-value model.
3. Add the standalone `audio-visualizer` widget and configuration schema.
4. Add permission and unavailable states to regular and compact layouts.
5. Consider an optional Music Island visualization after the standalone path is
   stable.

## Reference Implementation

CAVA provides a working open-source reference for the macOS Core Audio Tap
approach. Its macOS configuration uses `method = coreaudio` with
`source = tap` or `source = tap_mono` on supported builds.

- [CAVA macOS configuration](https://github.com/karlstav/cava#macos-1)
- [CAVA Core Audio Tap implementation](https://github.com/karlstav/cava/blob/master/input/coreaudio_tap.m)
