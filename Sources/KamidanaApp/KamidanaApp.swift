import AppKit
import CoreWLAN
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarWindow: NSWindow!
    private var hostingController: NSHostingController<StatusBarView>?
    let barHeight: CGFloat = 600  // Enlarged height to support island expansion

    static let sharedDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        WidgetRegistry.shared.registerAllWidgets()
        let isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
        ConfigManager.shared.activateConfiguration(isBuiltIn: isBuiltInDisplay)
        ConfigManager.shared.startWatchingConfig()

        let contentView = StatusBarView()

        // Create initial window
        statusBarWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        statusBarWindow.level = .statusBar
        var collectionBehavior: NSWindow.CollectionBehavior = [.stationary, .ignoresCycle]
        statusBarWindow.backgroundColor = .clear
        statusBarWindow.hasShadow = false
        statusBarWindow.isOpaque = false

        if !ConfigManager.shared.globalV1Config.hideInFullscreen {
            print("[LOG CONFIG] Hide in full screen : false")
            collectionBehavior.insert(.canJoinAllSpaces)
            collectionBehavior.insert(.fullScreenAuxiliary)
        } else {
            print("[LOG CONFIG] Hide in full screen : true")
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleFullScreenEnter),
                name: NSWindow.didEnterFullScreenNotification, object: nil
            )

            NotificationCenter.default.addObserver(
                self, selector: #selector(handleFullScreenExit),
                name: NSWindow.didExitFullScreenNotification,
                object: nil
            )
        }
        statusBarWindow.collectionBehavior = collectionBehavior

        let hostingController = NSHostingController(rootView: contentView)
        self.hostingController = hostingController
        statusBarWindow.contentView = hostingController.view

        // Calculate initial window position
        updateWindowPosition()

        statusBarWindow.makeKeyAndOrderFront(nil)
        // statusBarWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        // Monitor display configuration changes (connect/disconnect, resolution changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindowPosition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Monitor wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateWindowPosition),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rerenderBar),
            name: NSNotification.Name("KamidanaConfigDidChange"),
            object: nil
        )
    }

    @objc func rerenderBar() {
        print("[LOG] rerenderBar called")
        hostingController?.rootView = StatusBarView()
        statusBarWindow.contentView?.needsDisplay = true
        statusBarWindow.contentView?.displayIfNeeded()
        updateWindowPosition()
    }

    @objc func handleFullScreenEnter(notification: Notification) {
        // 隠したい補助ウィンドウを非表示にする
        statusBarWindow.orderOut(nil)
    }

    // フルスクリーンから戻ったとき
    @objc func handleFullScreenExit(notification: Notification) {
        // render window FIX
        statusBarWindow.orderFrontRegardless()
    }
    // Reposition window forcibly to the top of the screen
    @objc func updateWindowPosition() {
        // Run asynchronously to wait for system screen info updates to complete
        DispatchQueue.main.async {
            guard let screen = NSScreen.screens.first else { return }
            let screenRect = screen.frame
            let barPadding = ConfigManager.shared.globalV1Config.barPadding

            let windowRect = Self.windowRect(
                for: screenRect,
                barHeight: self.barHeight,
                barPadding: barPadding
            )

            // Snap immediately to the correct position and size without animation
            self.statusBarWindow.setFrame(windowRect, display: true)
        }
    }

    static func windowRect(
        for screenRect: NSRect,
        barHeight: CGFloat,
        barPadding: KamidanaInsets
    ) -> NSRect {
        let top = CGFloat(barPadding.top)
        let bottom = CGFloat(barPadding.bottom)
        let leading = CGFloat(barPadding.leading)
        let trailing = CGFloat(barPadding.trailing)
        let width = max(0, screenRect.width - leading - trailing)
        let height = max(0, barHeight - top - bottom)
        return NSRect(
            x: screenRect.minX + leading,
            y: screenRect.maxY - top - height,

            width: width,
            height: height
        )
    }
}

struct StatusBarView: View {
    // Initialize SystemMatrix
    @StateObject private var matrix = SystemMatrix(
        args: SystemMatrixArgs(
            cpu: true,
            memory: true,
            disk: true,  // For disk I/O
            internet: true,
            power: true,  // For battery calculation
            gpu: true,
            thermal: true,
            battery: true  // For battery UI
        ))

    // Initialize LocalSend manager
    @StateObject private var localSend = LocalSendManager()

    // Initialize network manager
    @StateObject private var netManager = NetworkManager()

    // Initialize music manager (media playback)
    @StateObject private var musicManager = MusicPlayingManager()

    // Initialize audio manager
    @StateObject private var audioVM = AudioViewModel()
    @StateObject private var uiSettings = UISettingsStore()
    @StateObject private var bluetooth = BluetoothManager()

    @State private var currentScreen: NSScreen = NSScreen.screens.first ?? NSScreen.main!
    @State private var configReloadToken = UUID()

    var body: some View {
        let isBuiltInDisplay = DisplayDetector.isBuiltIn(screen: currentScreen)
        let v1Configuration = ConfigManager.shared.configuration(for: currentScreen)
        let currentLayout: DisplayLayoutConfig = ConfigManager.shared.layout(for: currentScreen)
        let globalMode = v1Configuration?.global.backgroundMode ?? .perWidget
        let leftMode = v1Configuration?.left.backgroundMode ?? globalMode
        let centerMode = v1Configuration?.center.backgroundMode ?? globalMode
        let rightMode = v1Configuration?.right.backgroundMode ?? globalMode
        let globalStyle = v1Configuration?.global.style
        let leftStyle = mergedStyle(globalStyle, v1Configuration?.left.style)
        let centerStyle = mergedStyle(globalStyle, v1Configuration?.center.style)
        let rightStyle = mergedStyle(globalStyle, v1Configuration?.right.style)

        ZStack(alignment: .top) {
            // Left widget group
            HStack(spacing: CGFloat(v1Configuration?.left.style.spacing ?? 8)) {
                ForEach(currentLayout.left, id: \.id) { instance in
                    if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
                        factory.makeView(config: instance.config)
                            .environment(\.kamidanaV1Style, instance.v1Style)
                            .environment(\.kamidanaPopupStyle, instance.v1PopupStyle)
                            .environment(\.kamidanaWidgetFormat, instance.v1Format)
                            .environment(\.kamidanaWidgetActivation, instance.v1Activate)
                            .kamidanaWidgetMotion(instance.v1Motion)
                            .environment(\.showsKamidanaWidgetSurface, leftMode == .perWidget)
                    }
                }
            }
            .kamidanaSectionSurface(style: leftStyle, isEnabled: leftMode == .perSection)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.top, 5)
            .environment(\.kamidanaPopupHorizontalAlignment, .leading)
            .zIndex(200)

            // Right widget group
            HStack(
                alignment: .top,
                spacing: CGFloat(v1Configuration?.right.style.spacing ?? 8),
                content: {
                    ForEach(currentLayout.right, id: \.id) { instance in
                        if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
                            factory.makeView(config: instance.config)
                                .environment(\.kamidanaV1Style, instance.v1Style)
                                .environment(\.kamidanaPopupStyle, instance.v1PopupStyle)
                                .environment(\.kamidanaWidgetFormat, instance.v1Format)
                                .environment(\.kamidanaWidgetActivation, instance.v1Activate)
                                .kamidanaWidgetMotion(instance.v1Motion)
                                .environment(\.showsKamidanaWidgetSurface, rightMode == .perWidget)
                        }
                    }
                }
            )
            .kamidanaSectionSurface(style: rightStyle, isEnabled: rightMode == .perSection)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)
            .padding(.top, 5)
            .environment(\.kamidanaPopupHorizontalAlignment, .trailing)
            .zIndex(200)

            // Keep the Island geometrically centered. On built-in displays this aligns the
            // compact state with the camera/notch instead of moving with the left section.
            KamidanaIsland(
                centerWidgets: currentLayout.center,
                isBuiltInDisplay: isBuiltInDisplay
            )
            .environment(\.showsKamidanaWidgetSurface, centerMode == .perWidget)
            .environment(\.kamidanaPopupHorizontalAlignment, .center)
            .fixedSize()
            .kamidanaSectionSurface(style: centerStyle, isEnabled: centerMode == .perSection)
            .padding(.top, isBuiltInDisplay ? 0 : 7)
            .zIndex(100)
        }
        .kamidanaSectionSurface(
            style: globalStyle,
            isEnabled: globalMode == .singleBar,
            includesPadding: false,
            outerPadding: currentLayout.barPadding,
            appliesOuterPaddingToContent: false,
            hideBorderWhenOuterPaddingIsZero: true
        )
        .environment(\.widgetStyle, currentLayout.style)
        .environmentObject(netManager)
        .environmentObject(audioVM)
        .environmentObject(matrix)
        .environmentObject(bluetooth)
        .environmentObject(musicManager)
        .font(.system(size: isBuiltInDisplay ? 13 : 14, weight: .semibold, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: 600, alignment: .top)
        .background(Color.clear)
        .onAppear {
            matrix.startMonitoring()
            localSend.scanNetwork()
            if let screen = NSScreen.screens.first { currentScreen = screen }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            DispatchQueue.main.async {
                if let screen = NSScreen.screens.first { currentScreen = screen }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ConfigManager.configDidChangeNotification
            )
        ) { _ in
            DispatchQueue.main.async {
                configReloadToken = UUID()
            }
        }
    }

    private func mergedStyle(
        _ parent: KamidanaStyle?,
        _ child: KamidanaStyle?
    ) -> KamidanaStyle? {
        guard let parent else { return child }
        guard let child else { return parent }
        return KamidanaConfigurationV1Adapter.mergedStyle(parent, child)
    }
}
