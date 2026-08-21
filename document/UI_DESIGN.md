# UI Design Guidelines

This document defines the core UI architecture and design principles of Kamidana. These specifications are foundational, and all pull requests must strictly follow them.

> *Do not modify this document without repository maintainer permission.*

---

## User Customization Boundary

All widgets, including regular status-bar widgets and center widgets, must have their supported UI structures and interaction states defined by the application.

Users may configure which predefined widgets and UI parts are displayed and may customize their colors, format content, and Nerd Font icons. Users may not directly specify coordinates, constraints, or the internal position of UI elements. Configuration selects and styles application-defined UI; it does not create arbitrary layouts.

Consequently, the application must predefine the visual and interaction behavior for every supported state. This includes the UI shown when a widget, control, action, or optional UI part is disabled. Any new configuration option that can disable or hide functionality must be accompanied by an application-defined disabled-state layout, behavior, and transition.

---

## Status Bar Layout

The primary user interface of Kamidana is the top status bar, implemented in [`KamidanaApp.swift`](../Sources/Kamidana/KamidanaApp.swift).

The bar is divided into three distinct layout sections:
1. **Left Section**: Quick utility controls
2. **Center Section (Kamidana Island)**: Interactive dynamic notch & media island
3. **Right Section**: System metrics and monitoring widgets

---

## Compact Mode

Kamidana features an adaptive display mechanism called **Compact Mode**.

### Why Compact Mode is Needed
MacBook built-in displays feature a physical camera notch in the top-center of the screen. If the standard external-display layout were used on a built-in screen, widgets would collide with and be obscured by the notch frame.

### How it Works
- Managed automatically via the `compactMode` environment variable.
- Activated when the app detects that the active screen is a MacBook built-in display.
- In Compact Mode:
  - Widget padding and font sizes are slightly reduced.
  - The center Island shifts its alignment to integrate directly around the notch area.
  - Less critical system widgets in the right section are collapsed into a foldable popup menu (`FoldedWidgetsButton`) to keep the bar uncluttered.

---

## Section Breakdown

### 1. Left Section (Utility Controls)
Hosts essential system operation and connectivity widgets:
- **System Control Widget**: Power controls (Sleep, Restart, Shutdown, Lock, About This Mac) and btop terminal launcher.
- **Network Widget**: Wired and wireless status, address details, transfer speed, and Wi-Fi connection manager.
- **Audio Widget**: Volume levels, microphone mute toggle, and input/output device selector.

### 2. Center Section (Kamidana Island)
Kamidana Island is a dynamic, smooth interactive component inspired by modern notch interfaces. It seamlessly expands when hovered over by the cursor.

#### Widget States & Expansion Behavior
1. **Default State (Collapsed)**: Displays minimal, ambient information when not hovered (e.g., current song title or music icon).
2. **Hovered State (Expanded)**: Expands into a rich interactive view showing album artwork, playback controls, seek bar, time elapsed, and supplemental widgets (e.g., weather or system actions).
3. **Tabbed Navigation**: When expanded, the Island supports tabs to switch between different rich views:
   - **Tab 1**: Media & Music player controls
   - **Tab 2**: System monitor / Btop summary
   - **Tab 3**: Custom development metrics (e.g., Xcode monthly usage)

#### Customization: Disabling Hover Expansion
- By default, the Island expands on cursor hover to reveal rich UI controls.
- **User Preference**: Users can disable this hover expansion via configuration settings. When disabled, the Island behaves like a standard static widget (displaying ambient info without expanding on hover).

### 3. Right Section (System Monitors)
Hosts real-time hardware and resource monitoring widgets:
- **Full Mode (External Displays)**: Displays all metrics expanded (Network speed, CPU, GPU, Memory, Disk I/O, Bluetooth, Battery, Clock).
- **Compact Mode (Built-in Displays)**: Displays core widgets (CPU, Memory, Battery, Clock) and moves secondary widgets (Network, GPU, Disk) into the foldable drawer button (`FoldedWidgetsButton`).
