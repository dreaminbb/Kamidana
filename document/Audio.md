# Audio Module Specification

CoreAudio (HAL) を利用して以下の機能を提供する。

## 機能一覧

- スピーカー音量の取得
- スピーカー音量の変更
- スピーカーミュートの取得
- スピーカーミュートの切り替え
- マイク入力レベルの取得
- マイク入力レベルの変更
- マイクミュートの取得
- マイクミュートの切り替え（対応デバイスのみ）
- 入力デバイス一覧取得
- 出力デバイス一覧取得
- デフォルト入力デバイス変更
- デフォルト出力デバイス変更
- デバイス接続・切断の監視
- 音量変更の監視
- ミュート状態変更の監視

---

# 使用フレームワーク

- CoreAudio
- AudioHardware (HAL)

---

# CoreAudio API

## AudioObject

| API | 用途 |
|------|------|
| `AudioObjectGetPropertyData` | プロパティ取得 |
| `AudioObjectSetPropertyData` | プロパティ変更 |
| `AudioObjectAddPropertyListenerBlock` | 変更通知登録 |
| `AudioObjectRemovePropertyListenerBlock` | 通知解除 |

---

# 使用するProperty

## デバイス一覧

```swift
kAudioHardwarePropertyDevices
```

取得型

```swift
[AudioDeviceID]
```

---

## デフォルト出力

```swift
kAudioHardwarePropertyDefaultOutputDevice
```

取得型

```swift
AudioDeviceID
```

---

## デフォルト入力

```swift
kAudioHardwarePropertyDefaultInputDevice
```

取得型

```swift
AudioDeviceID
```

---

## デバイス名

```swift
kAudioObjectPropertyName
```

取得型

```swift
CFString
```

---

## Device UID

```swift
kAudioDevicePropertyDeviceUID
```

取得型

```swift
CFString
```

---

## Input / Output判定

```swift
kAudioDevicePropertyStreams
```

Scope

```swift
kAudioObjectPropertyScopeInput
kAudioObjectPropertyScopeOutput
```

---

## 音量

```swift
kAudioDevicePropertyVolumeScalar
```

型

```swift
Float32
```

値

```
0.0〜1.0
```

---

## ミュート

```swift
kAudioDevicePropertyMute
```

型

```swift
UInt32
```

値

```
0 = OFF
1 = ON
```

---

# Property Listener

監視対象

```swift
kAudioHardwarePropertyDevices

kAudioHardwarePropertyDefaultInputDevice

kAudioHardwarePropertyDefaultOutputDevice

kAudioDevicePropertyVolumeScalar

kAudioDevicePropertyMute
```

利用API

```swift
AudioObjectAddPropertyListenerBlock
```

---

# データモデル

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

# Manager構成

## AudioDeviceManager

責務

- デバイス一覧取得
- デフォルト入力取得
- デフォルト出力取得
- デフォルト入力変更
- デフォルト出力変更

主な関数

```swift
func devices() -> [AudioDevice]

func defaultInput() -> AudioDevice

func defaultOutput() -> AudioDevice

func setInput(_ device: AudioDevice)

func setOutput(_ device: AudioDevice)
```

---

## AudioVolumeManager

責務

- 音量取得
- 音量変更
- ミュート取得
- ミュート変更

主な関数

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

責務

- CoreAudio Property Listener登録
- 通知の管理
- SwiftUIへの通知

主な関数

```swift
func start()

func stop()
```

---

# ViewModel

## AudioViewModel

保持する状態

```swift
@Published var devices

@Published var outputDevice

@Published var inputDevice

@Published var outputVolume

@Published var inputVolume
```

責務

- UIとのバインディング
- Managerの呼び出し
- Listenerからの更新反映

---

# ディレクトリ構成

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

# 将来的な拡張

- 左右チャンネル個別音量
- サンプルレート変更
- ビット深度変更
- Audio Aggregate Device対応
- AirPlay対応
- Bluetoothデバイス情報取得
- Audio MIDI Setupとの同期
- 入出力VUメーター
- 仮想オーディオデバイス対応（BlackHole・Loopbackなど）
