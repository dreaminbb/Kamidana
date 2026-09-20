import AppKit
import CoreWLAN
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [CGDirectDisplayID: StatusBarWindowController] = [:]
    private let launchAtLoginManager = LaunchAtLoginManager()
    let barHeight: CGFloat = 600  // Enlarged height to support island expansion

    static let sharedDelegate = AppDelegate()

    public static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.run()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        WidgetRegistry.shared.registerAllWidgets()
        let isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
        ConfigManager.shared.activateConfiguration(isBuiltIn: isBuiltInDisplay)
        launchAtLoginManager.synchronize(
            isEnabled: ConfigManager.shared.globalV1Config.launchAtLogin
        )
        ConfigManager.shared.startWatchingConfig()

        updateWindows()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleRuntimeExplanationRequest(_:)),
            name: .kamidanaRuntimeExplanationRequest,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateWindows),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigChange),
            name: ConfigManager.configDidChangeNotification,
            object: nil
        )
    }

    @objc func handleConfigChange() {
        launchAtLoginManager.synchronize(
            isEnabled: ConfigManager.shared.globalV1Config.launchAtLogin
        )
        updateWindows()
    }

    @objc func updateWindows() {
        DispatchQueue.main.async {
            let displays = self.resolveDisplays()
            var activeIDs = Set<CGDirectDisplayID>()

            for display in displays {
                activeIDs.insert(display.id)
                if let existing = self.windowControllers[display.id] {
                    existing.updateConfiguration()
                } else {
                    let controller = StatusBarWindowController(displayID: display.id, barHeight: self.barHeight)
                    self.windowControllers[display.id] = controller
                    controller.showWindow()
                }
            }

            for id in self.windowControllers.keys {
                if !activeIDs.contains(id) {
                    self.windowControllers[id]?.closeWindow()
                    self.windowControllers.removeValue(forKey: id)
                }
            }
        }
    }

    @objc private func handleRuntimeExplanationRequest(_ notification: Notification) {
        let requestID = notification.userInfo?["request_id"] as? String
        ConfigManager.shared.publishRuntimeExplanation(requestID: requestID)
    }

    private func resolveDisplays() -> [KamidanaDisplayTargetScreen] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return [] }

        var targetScreens: [KamidanaDisplayTargetScreen] = []
        for screen in screens {
            guard let id = DisplayDetector.displayID(for: screen) else { continue }
            targetScreens.append(
                KamidanaDisplayTargetScreen(
                    id: id,
                    name: screen.localizedName,
                    isBuiltIn: DisplayDetector.isBuiltIn(screen: screen),
                    isPrimary: screen == screens.first
                )
            )
        }

        return KamidanaDisplayTargetResolver.resolve(
            targets: ConfigManager.shared.globalV1Config.displayTargets,
            screens: targetScreens
        )
    }
}

class StatusBarWindowController {
    let displayID: CGDirectDisplayID
    let barHeight: CGFloat
    let window: StatusBarWindow
    private var hostingController: NSHostingController<StatusBarView>?
    private var fullscreenObserverEnter: NSObjectProtocol?
    private var fullscreenObserverExit: NSObjectProtocol?

    init(displayID: CGDirectDisplayID, barHeight: CGFloat) {
        self.displayID = displayID
        self.barHeight = barHeight

        self.window = StatusBarWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isOpaque = false

        let contentView = StatusBarView(displayID: displayID)
        let hostingController = NSHostingController(rootView: contentView)
        self.hostingController = hostingController
        window.contentView = hostingController.view

        updateConfiguration()
    }

    func showWindow() {
        window.orderFront(nil)
        NativelyBarWindowBridge.shared.configure(window: window)
        updateWindowPosition()
    }

    func closeWindow() {
        window.orderOut(nil)
        if let enter = fullscreenObserverEnter {
            NotificationCenter.default.removeObserver(enter)
        }
        if let exit = fullscreenObserverExit {
            NotificationCenter.default.removeObserver(exit)
        }
    }

    func updateConfiguration() {
        let hideInFullscreen = ConfigManager.shared.globalV1Config.hideInFullscreen
        var collectionBehavior: NSWindow.CollectionBehavior = [.stationary, .ignoresCycle]

        if let enter = fullscreenObserverEnter {
            NotificationCenter.default.removeObserver(enter)
            fullscreenObserverEnter = nil
        }
        if let exit = fullscreenObserverExit {
            NotificationCenter.default.removeObserver(exit)
            fullscreenObserverExit = nil
        }

        if !hideInFullscreen {
            collectionBehavior.insert(.canJoinAllSpaces)
            collectionBehavior.insert(.fullScreenAuxiliary)
        } else {
            fullscreenObserverEnter = NotificationCenter.default.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.window.orderOut(nil)
            }

            fullscreenObserverExit = NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                self.window.orderFront(nil)
                NativelyBarWindowBridge.shared.configure(window: self.window)
            }
        }
        window.collectionBehavior = collectionBehavior

        hostingController?.rootView = StatusBarView(displayID: displayID)
        window.contentView?.needsDisplay = true
        window.contentView?.displayIfNeeded()

        updateWindowPosition()
    }

    func updateWindowPosition() {
        guard let screen = NSScreen.screens.first(where: { DisplayDetector.displayID(for: $0) == displayID }) else { return }
        let screenRect = screen.frame
        let barPadding = ConfigManager.shared.globalV1Config.barPadding

        let windowRect = AppDelegate.windowRect(
            for: screenRect,
            barHeight: barHeight,
            barPadding: barPadding
        )

        window.setFrame(windowRect, display: true)
    }
}

extension AppDelegate {
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
    // Shared states
    @StateObject private var matrix = SystemMatrix(
        args: SystemMatrixArgs(
            cpu: true,
            memory: true,
            disk: true,
            internet: true,
            power: true,
            gpu: true,
            thermal: true,
            battery: true
        ))

    @StateObject private var localSend = LocalSendManager()
    @StateObject private var netManager = NetworkManager()
    @StateObject private var musicManager = MusicPlayingManager()
    @StateObject private var audioVM = AudioViewModel()
    @StateObject private var bluetooth = BluetoothManager()

    let displayID: CGDirectDisplayID

    private var currentScreen: NSScreen {
        NSScreen.screens.first(where: { DisplayDetector.displayID(for: $0) == displayID }) ?? NSScreen.main!
    }

    var body: some View {
        let screen = currentScreen
        let isBuiltInDisplay = DisplayDetector.isBuiltIn(screen: screen)
        let v1Configuration = ConfigManager.shared.configuration(for: screen)
        let currentLayout = ConfigManager.shared.layout(for: screen)
        let builtInTopInset = isBuiltInDisplay ? screen.safeAreaInsets.top : 0
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
                            .environment(\.theme, instance.theme)
                            .environment(\.popupTheme, instance.popupTheme)
                            .environment(\.kamidanaWidgetFormat, instance.v1Format)
                            .environment(\.kamidanaWidgetActivation, instance.v1Activate)
                            .kamidanaWidgetAnimation(instance.v1Animation)
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
                                .environment(\.theme, instance.theme)
                                .environment(\.popupTheme, instance.popupTheme)
                                .environment(\.kamidanaWidgetFormat, instance.v1Format)
                                .environment(\.kamidanaWidgetActivation, instance.v1Activate)
                                .kamidanaWidgetAnimation(instance.v1Animation)
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
                isBuiltInDisplay: isBuiltInDisplay,
                builtInTopInset: builtInTopInset
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
        .environmentObject(netManager)
        .environmentObject(audioVM)
        .environmentObject(matrix)
        .environmentObject(bluetooth)
        .environmentObject(musicManager)
        .font(.system(size: isBuiltInDisplay ? 13 : 14, weight: .semibold, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: 600, alignment: .top)
        .background(Color.clear)
        .ignoresSafeArea(.all)
        .onAppear {
            matrix.startMonitoring()
            localSend.scanNetwork()
        }
    }

    private func mergedStyle(_ parent: KamidanaStyle?, _ child: KamidanaStyle?) -> KamidanaStyle? {
        guard let parent else { return child }
        guard let child else { return parent }
        return KamidanaConfigurationV1Adapter.mergedStyle(parent, child)
    }
}
