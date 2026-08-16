import SwiftUI

struct SystemControlWidget: View {
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
        let config = ConfigManager.shared.currentConfig.systemControl
        let colors = ConfigManager.shared.currentConfig.colors
        let terminalUI = TerminalView(executable: config.terminalPath)
            .background(Color(hex: colors.background).opacity(0.8))
            .background(.ultraThinMaterial)  // Frosted glass effect

        // NSHostingView bridges SwiftUI and AppKit (NSWindow)
        window.contentView = NSHostingView(rootView: terminalUI)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Bring window to front and focus
        window.makeKeyAndOrderFront(nil)
    }

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        // Base icon (matches layout and height of other widget buttons)
        HStack(spacing: 4) {
            let config = ConfigManager.shared.currentConfig.systemControl
            NerdFontIcon(config.icon, size: 14)
                .foregroundColor(Color(hex: config.iconColor))
                .frame(width: 20, alignment: .center) // Set 20px width and center alignment
        }
        .SmoothUIModule() // Matches size and position with other modules
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
                                icon: "󰌢", color: Color(hex: colors.info), text: "About this Mac"
                            ) {
                                let _ = systemController.showAboutThisMac()
                            }

                            menuButton(icon: "󰒲", color: Color(hex: colors.info), text: "Sleep") {
                                let _ = systemController.sleepSystem()
                            }

                            menuButton(icon: "⏻", color: Color(hex: colors.danger), text: "Shutdown") {
                                let _ = systemController.shutdownSystem()
                            }

                            menuButton(
                                icon: "󰑐", color: Color(hex: colors.warning),
                                text: "Reboot"
                            ) {
                                let _ = systemController.rebootSystem()
                            }

                            menuButton(
                                icon: "󰈆", color: Color(hex: colors.primary),
                                text: "Logout"
                            ) {
                                let _ = systemController.logoutSystem()
                            }

                            menuButton(icon: "󰌾", color: Color(hex: colors.accent), text: "Screen Lock") {
                                let _ = systemController.lockScreen()
                            }

                        }
                        // Match leading padding with SmoothUIModule to align vertical axis
                        .padding(.leading, compactMode ? 8 : 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: colors.background))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: colors.surfaceHighlight), lineWidth: 1)
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
        icon: String, color: Color, text: String, action: @escaping () -> Void
    ) -> some View {
        let colors = ConfigManager.shared.currentConfig.colors
        return Button(action: action) {
            HStack(spacing: 10) {
                NerdFontIcon(icon, size: 14)
                    .foregroundColor(color)
                    .frame(width: 20, alignment: .center)

                Text(text)
                    .foregroundColor(Color(hex: colors.textPrimary))
            }
        }
        .buttonStyle(.plain)
    }
}
