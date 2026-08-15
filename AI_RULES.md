# AI Assistant Development Guidelines (AI Rules)

These rules and guidelines must be strictly adhered to by all AI assistants generating, modifying, or reviewing code in the **Kamidana** project.

---

## 0. [MANDATORY] Pre-Implementation Documentation Review
Before writing or modifying any code, designing UI components, or implementing new features, the AI assistant **MUST read and follow all relevant documents in the `document/` directory** to understand the architecture, design principles, and project standards.

Key Reference Documents:
- [`document/UI_DESIGN.md`](document/UI_DESIGN.md): UI architecture, Compact Mode, Island specifications, and widget design principles.
- [`document/Logging.md`](document/Logging.md): Logging standards and guidelines.
- [`document/CompactUI.md`](document/CompactUI.md): Compact Mode implementation guidelines.
- [`document/Audio.md`](document/Audio.md): CoreAudio / AudioDeviceManager specifications.
- [`document/SwiftTermUsage.md`](document/SwiftTermUsage.md): Embedded terminal integration details.

---

## 1. OSS Architectural Foundation & Development Consistency
Kamidana is built as a collaborative, open-source status bar engine inspired by YASB. To support long-term scalability and external contributors:

1. **Foundational Architecture Over Quick-Wins**:
   - Always prioritize decoupled, configuration-driven infrastructure (e.g., config parsers, dynamic widget registries, modular manager services) over hardcoding one-off features directly into views.
   - Adding features through ad-hoc hardcoding in `StatusBarView` introduces technical debt and causes merge conflicts for OSS contributors. Build the proper architectural foundation first.
2. **Strict Consistency Across Features**:
   - All widgets must strictly adhere to the same design tokens, lifecycle patterns, and modular modifier standards (`.SmoothUIModule(theme:)`, monospaced dynamic metrics, `NerdFontIcon` constructor sizing).
   - Ensure new code is modular, reusable, and self-contained so other developers can follow existing patterns as reference implementations.
3. **Objective Technical Honesty (Anti-Sycophancy)**:
   - When evaluating roadmaps, architecture, or priority trade-offs, provide grounded, objective technical reasoning. Never compromise on architectural integrity or switch technical stances merely to appease the user.

---

## 2. Core AI Constraints & Code Quality Standards
To maintain high code quality, readability, and portability as an open-source project:

1. **English Only**:
   - All source code, identifiers, comments (`//`, `///`), docstrings, commit messages, and log messages **must be written in English**.
2. **Strictly No Emojis**:
   - **Do not include emojis** in source comments, `print` statements, error logs, or code identifiers.
3. **No Hardcoded User Paths**:
   - Never write absolute paths tied to a specific user environment (e.g., `/Users/username/...`). Always use dynamic path resolution (`Bundle.main.resourcePath`, `Bundle.main.bundlePath`, `FileManager.default`, or relative fallbacks).
4. **Icon Usage Standard (`NerdFontIcon`)**:
   - Do not use SF Symbols or raw emojis directly in widgets. Use `NerdFontIcon` mapped in [`nerdfont.toml`](nerdfont.toml).
   - **Always pass size directly to the constructor**: Use `NerdFontIcon(.<icon>, size: xx)`. Do **NOT** set the icon size using chained `.font(.system(size: xx))` or `.frame(...)` modifiers.
     ```swift
     // Recommended
     NerdFontIcon(.music, size: 18)
     NerdFontIcon(.appleLogo, size: 14)

     // Prohibited
     NerdFontIcon(.music).font(.system(size: 18))
     ```
5. **Clean & Silent Logging**:
   - Avoid noisy, continuous print statements inside timer callbacks or periodic polling loops.
6. **Robustness & Crash Prevention**:
   - Always implement safe unwrapping of optionals and proper error handling (`do-catch`).
   - Be mindful of AppKit delegate lifecycles (e.g., preventing premature deallocation of `weak` references like `NSApplication.shared.delegate`).

---

## 3. Architecture & System Design Rules

### View & Model Separation
- Keep SwiftUI `View` bodies purely declarative and lightweight.
- Move heavy data fetching, system polling, process inspection, and C-API bindings (CoreAudio, CoreWLAN, IOBluetooth, mach kernel APIs) into dedicated manager classes conforming to `ObservableObject`.
- Place backend managers in `Sources/Kamidana/module/` or `Sources/Kamidana/Audio/`.

### Threading & UI Safety
- **Main Thread UI Updates**: Any mutation to `@Published` properties that drives UI re-renders must occur on the main thread (`DispatchQueue.main.async` or `@MainActor`).
- **Background Execution**: Perform heavy system inspection, process monitoring, disk I/O calculations, and shell commands on background queues (`DispatchQueue.global(qos: .utility)` or `.userInitiated`). Never block the main thread.

### Widget Consistency & Theming
- **Module Wrapper**: All standalone status bar widgets must be wrapped with `.SmoothUIModule(theme:)` to ensure uniform frosted glass backgrounds (`.ultraThinMaterial`), corner radiuses, padding, and hover states.
- **Semantic Colors**: Never hardcode colors (`Color.red`, raw RGB/Hex values). Always use semantic tokens from the active `Theme` instance (e.g., `theme.textPrimary`, `theme.textSecondary`, `theme.accent`, `theme.surface`, `theme.warning`, `theme.caution`).
- **Layout Stability**: Use `.monospaced` or `.monospacedDigit()` for real-time dynamic numerical values (CPU %, RAM usage, network speeds, clock) to prevent UI jitter and width fluctuations.

---

## 4. Function & Identifier Naming Conventions

Follow the official **Swift API Design Guidelines**:

### Functions & Methods
- **Action Verbs for Mutating / Imperative Operations**: Name methods starting with clear verbs describing the action:
  - `startMonitoring()`, `stopMonitoring()`
  - `fetchAvailableNetworks()`, `scanForDevices()`
  - `toggleMute()`, `changeTrack(direction:)`, `seek(to:)`
  - `updateWindowPosition()`
- **Noun Phrases for Non-Mutating Accessors / Formatters**:
  - `formattedBandwidth(bytes:) -> String`
  - `resolveConfigPath() -> String?`

### Properties & Variables
- **Boolean Properties**: Must read as assertions. Prefix with `is`, `has`, `can`, or `should`:
  - `isPlaying`, `isHovered`, `isBluetoothOn`, `isInputMuted`
  - `hasBattery`, `canExpand`
- **State & Observable Objects**:
  - `@StateObject private var netManager = NetworkManager()`
  - `@ObservedObject var musicManager: MusicPlayingManager`

### Types & Protocols
- **Types (Classes, Structs, Enums)**: Use UpperCamelCase (PascalCase) with descriptive nouns:
  - `BluetoothManager`, `SystemMatrix`, `NerdFontIconType`
- **Protocols**:
  - Use nouns for what something is: `AudioListener`
  - Use `-able` or `-ible` suffixes for describing capabilities: `Themeable`, `ConfigurableWidget`
- **Enum Cases**: Use lowerCamelCase:
  - `.bluetooth`, `.appleLogo`, `.batteryHalf`, `.arrowClockwise`

---

## 5. Communication & File Editing Principles
- **Response Language**: Communicate with the user in Japanese (or user's preferred language), while keeping all codebase artifacts in English.
- **Conciseness**: Keep responses clear, concise, and focused. Avoid unnecessary fluff.
- **Pinpoint Edits**: Make surgical, minimal edits only to relevant sections of files. Do not modify unrelated files.
- **No Assumptions**: If the user's intent is ambiguous or involves destructive refactoring, confirm with the user before proceeding.
