# Custom Terminal Implementation Guide using SwiftTerm (for Kamidana)

This document outlines the implementation steps and key points for embedding a custom-themed, translucent terminal window into the Kamidana app in a SwiftUI (macOS) environment using `SwiftTerm` to display tools like `btop` and `fastfetch`.

## 1. Core Components of SwiftTerm

SwiftTerm provides views for each platform. On macOS, **`LocalProcessTerminalView`** (a subclass of `NSView`) is used to directly execute and render local shell processes (commands).

## 2. Integration and Embedding into SwiftUI

### Adding the Package
Add the following to dependencies in `Package.swift`:
`https://github.com/migueldeicaza/SwiftTerm.git`

### Creating the SwiftUI Wrapper (NSViewRepresentable)
To display it in SwiftUI, wrap it with `NSViewRepresentable`.

```swift
import SwiftUI
import SwiftTerm

struct TerminalView: NSViewRepresentable {
    var executable: String
    var theme: Theme
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView()
        
        // [Important] Specify the absolute path since the Homebrew PATH is not available in GUI apps
        terminal.startProcess(executable: executable, args: [])
        
        // Apply theme and design (described below)
        applyTheme(to: terminal)
        
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
```

## 3. Design and Theme Customization (Important)

These configuration items achieve the requirements: "color scheme matching the app theme" and "translucent background."

### A. Making the Background Translucent
Make the terminal's own background transparent and apply a glass effect (`ultraThinMaterial`) using SwiftUI modifiers.

```swift
// Make the SwiftTerm background transparent
terminal.nativeBackgroundColor = NSColor.clear
terminal.isTransparent = true // Enable background transparency
```

When calling from SwiftUI:
```swift
TerminalView(executable: "/opt/homebrew/bin/btop", theme: theme)
    .background(theme.base.opacity(0.6)) // Translucent with Kamidana theme color
    .background(.ultraThinMaterial)      // Frosted glass effect
```

### B. Overriding the Color Scheme (ANSI Colors)
To perfectly match the colors output by `btop` and `fastfetch` with Kamidana's Catppuccin theme, override the terminal's color palette (16 ANSI colors).

```swift
func applyTheme(to terminal: LocalProcessTerminalView) {
    // 1. Base foreground text color
    terminal.nativeForegroundColor = NSColor(theme.text)
    
    // 2. Override ANSI color palette (16 colors)
    // Replace standard colors like "Red" or "Blue" with Kamidana custom theme colors
    let ansiColors: [NSColor] = [
        NSColor(theme.surface0), // 0: Black
        NSColor(theme.red),      // 1: Red
        NSColor(theme.green),    // 2: Green
        NSColor(theme.yellow),   // 3: Yellow
        NSColor(theme.blue),     // 4: Blue
        NSColor(theme.mauve),    // 5: Magenta
        NSColor(theme.teal),     // 6: Cyan
        NSColor(theme.subtext1), // 7: White
        // --- Map Bright colors to matching or slightly brighter shades ---
        NSColor(theme.surface1), // 8: Bright Black
        NSColor(theme.red),      // 9: Bright Red
        NSColor(theme.green),    // 10: Bright Green
        NSColor(theme.peach),    // 11: Bright Yellow
        NSColor(theme.blue),     // 12: Bright Blue
        NSColor(theme.mauve),    // 13: Bright Magenta
        NSColor(theme.teal),     // 14: Bright Cyan
        NSColor(theme.text)      // 15: Bright White
    ]
    
    // Apply to SwiftTerm palette
    terminal.installColors(colors: ansiColors)
}
```

## 4. Opening the Window

Add a dedicated `WindowGroup` for the terminal in the main `KamidanaApp.swift`.

```swift
WindowGroup("System Monitor", id: "BtopWindow") {
    TerminalView(executable: "/opt/homebrew/bin/btop", theme: Theme.catppuccinMocha)
        .frame(width: 800, height: 600)
}
.windowStyle(.hiddenTitleBar) // Hide title bar for a clean look
```

Then, simply calling `openWindow(id: "BtopWindow")` from a widget button will instantly launch a beautiful, native terminal fully unified with the theme.
