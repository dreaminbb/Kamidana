import SwiftUI

struct SystemControlWidget: View {
    var theme: Theme
    let systemController = SystemController()

    @State private var isHovered = false
    @Environment(\.compactMode) var compactMode: Bool  // Match padding with other widgets
    @Environment(\.openWindow) private var openWindow

    func openBtopTerminalWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1500, height: 1000),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Settings for translucent frosted glass appearance
        window.titlebarAppearsTransparent = true  // Make title bar transparent
        window.titleVisibility = .hidden  // Hide title text
        window.backgroundColor = .clear  // Make window background color transparent
        window.isOpaque = false  // Allow transparency for frosted glass effect
        window.center()  // Center on screen

        // Embed SwiftUI View into AppKit window with translucent styling
        let terminalUI = TerminalView(executable: "/opt/homebrew/bin/btop", theme: theme)
            .background(theme.background.opacity(0.8))
            .background(.ultraThinMaterial)  // Frosted glass effect

        // NSHostingView bridges SwiftUI and AppKit (NSWindow)
        window.contentView = NSHostingView(rootView: terminalUI)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Bring window to front and focus
        window.makeKeyAndOrderFront(nil)
    }

    var body: some View {
        // Base icon (matches layout and height of other widget buttons)
        HStack(spacing: 4) {
            NerdFontIcon(.appleLogo, size: 14)
                .foregroundColor(theme.secondary)
                .frame(width: 20, alignment: .center) // Set 20px width and center alignment
        }
        .SmoothUIModule(theme: theme) // Matches size and position with other modules
        // Menu that expands on hover is placed in the background
        .background(
            Group {
                if isHovered {
                    VStack(alignment: .leading, spacing: 4) {
                        // Header spacing matching button width:
                        Color.clear
                            .frame(width: compactMode ? 36 : 44, height: 28) // Match base width (20 + horizontal padding)

                        // Expanded menu body:
                        VStack(alignment: .leading, spacing: 12) {

                            menuButton(
                                icon: .laptop, color: theme.info, text: "About this Mac"
                            ) {
                                let _ = systemController.showAboutThisMac()
                            }

                            menuButton(icon: .bed, color: theme.info, text: "Sleep") {
                                let _ = systemController.sleepSystem()
                            }

                            menuButton(icon: .power, color: theme.danger, text: "Shutdown") {
                                let _ = systemController.shutdownSystem()
                            }

                            menuButton(
                                icon: .arrowClockwise, color: theme.warning,
                                text: "Reboot"
                            ) {
                                let _ = systemController.rebootSystem()
                            }

                            menuButton(
                                icon: .exit, color: theme.primary,
                                text: "Logout"
                            ) {
                                let _ = systemController.logoutSystem()
                            }

                            menuButton(icon: .lock, color: theme.accent, text: "Screen Lock") {
                                let _ = systemController.lockScreen()
                            }

                        }
                        // Match leading padding with SmoothUIModule to align vertical axis
                        .padding(.leading, compactMode ? 8 : 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .background(theme.background)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.surfaceHighlight, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    // Prevent clipping and allow expansion to text width using fixedSize
                    .fixedSize()
                    // Animation expanding downwards anchored at top-leading
                    .transition(.scale(scale: 0.01, anchor: .topLeading).combined(with: .opacity))
                }
            }, alignment: .topLeading
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .zIndex(100) // Prevent being hidden behind other widgets when expanded
    }

    // Helper to create consistent menu buttons
    private func menuButton(
        icon: NerdFontIconType, color: Color, text: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                NerdFontIcon(icon, size: 14)
                    .foregroundColor(color)
                    .frame(width: 20, alignment: .center)

                Text(text)
                    .foregroundColor(theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}
