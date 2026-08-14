# Audio Module Specification

Provides the following features using CoreAudio (HAL).

## Feature List

- Get speaker volume
- Set speaker volume
- Get speaker mute status
- Toggle speaker mute
- Get microphone input level
- Set microphone input level
- Get microphone mute status
- Toggle microphone mute (supported devices only)
- Get input device list
- Get output device list
- Set default input device
- Set default output device
- Monitor device connection / disconnection
- Monitor volume changes
- Monitor mute state changes

---

# Frameworks Used

- CoreAudio
- AudioHardware (HAL)

---

# CoreAudio API

## AudioObject

| API | Purpose |
|------|------|
| `AudioObjectGetPropertyData` | Get property |
| `AudioObjectSetPropertyData` | Set property |
| `AudioObjectAddPropertyListenerBlock` | Register property change notification |
| `AudioObjectRemovePropertyListenerBlock` | Unregister property change notification |

---

# Properties Used

## Device List

```swift
kAudioHardwarePropertyDevices
```

Return Type

```swift
[AudioDeviceID]
```

---

## Default Output

```swift
kAudioHardwarePropertyDefaultOutputDevice
```

Return Type

```swift
AudioDeviceID
```

---

## Default Input

```swift
kAudioHardwarePropertyDefaultInputDevice
```

Return Type

```swift
AudioDeviceID
```

---

## Device Name

```swift
kAudioObjectPropertyName
```

Return Type

```swift
CFString
```

---

## Device UID

```swift
kAudioDevicePropertyDeviceUID
```

Return Type

```swift
CFString
```

---

## Input / Output Determination

```swift
kAudioDevicePropertyStreams
```

Scope

```swift
kAudioObjectPropertyScopeInput
kAudioObjectPropertyScopeOutput
```

---

## Volume

```swift
kAudioDevicePropertyVolumeScalar
```

Type

```swift
Float32
```

Value

```
0.0 - 1.0
```

---

## Mute

```swift
kAudioDevicePropertyMute
```

Type

```swift
UInt32
```

Value

```
0 = OFF
1 = ON
```

---

# Property Listener

Monitored Properties

```swift
kAudioHardwarePropertyDevices

kAudioHardwarePropertyDefaultInputDevice

kAudioHardwarePropertyDefaultOutputDevice

kAudioDevicePropertyVolumeScalar

kAudioDevicePropertyMute
```

API Used

```swift
AudioObjectAddPropertyListenerBlock
```

---

# Data Models

## AudioDevice

```swift
struct AudioDevice {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isInput: Bool
    let isOutput: Bool
}
```

---

## AudioVolume

```swift
struct AudioVolume {
    var value: Float
    var muted: Bool
}
```

---

## AudioState

```swift
struct AudioState {
    var outputDevice: AudioDevice
    var inputDevice: AudioDevice

    var outputVolume: AudioVolume
    var inputVolume: AudioVolume
}
```

---

# Manager Structure

## AudioDeviceManager

Responsibilities

- Get device list
- Get default input device
- Get default output device
- Set default input device
- Set default output device

Main Methods

```swift
func devices() -> [AudioDevice]

func defaultInput() -> AudioDevice

func defaultOutput() -> AudioDevice

func setInput(_ device: AudioDevice)

func setOutput(_ device: AudioDevice)
```

---

## AudioVolumeManager

Responsibilities

- Get volume
- Set volume
- Get mute status
- Set mute status

Main Methods

```swift
func outputVolume() -> AudioVolume

func inputVolume() -> AudioVolume

func setOutputVolume(_ value: Float)

func setInputVolume(_ value: Float)

func setOutputMute(_ muted: Bool)

func setInputMute(_ muted: Bool)
```

---

## AudioListener

Responsibilities

- Register CoreAudio Property Listeners
- Manage notifications
- Notify SwiftUI

Main Methods

```swift
func start()

func stop()
```

---

# ViewModel

## AudioViewModel

State Properties

```swift
@Published var devices

@Published var outputDevice

@Published var inputDevice

@Published var outputVolume

@Published var inputVolume
```

Responsibilities

- UI binding
- Invoke managers
- Apply updates from listeners

---

# Directory Structure

```text
Audio/

├── Models/
│   ├── AudioDevice.swift
│   ├── AudioVolume.swift
│   └── AudioState.swift
│
├── Managers/
│   ├── AudioDeviceManager.swift
│   ├── AudioVolumeManager.swift
│   └── AudioListener.swift
│
├── ViewModels/
│   └── AudioViewModel.swift
│
└── Utilities/
    ├── AudioProperty.swift
    └── AudioError.swift
```

---

# Future Enhancements

- Individual left / right channel volume control
- Sample rate modification
- Bit depth modification
- Audio Aggregate Device support
- AirPlay support
- Retrieve Bluetooth device information
- Synchronization with Audio MIDI Setup
- Input / output VU meter
- Virtual audio device support (BlackHole, Loopback, etc.)
