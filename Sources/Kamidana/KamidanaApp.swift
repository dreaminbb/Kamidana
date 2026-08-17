import AppKit
import CoreWLAN
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var statusBarWindow: NSWindow!
  let barHeight: CGFloat = 600  // Enlarged height to support island expansion

  static let sharedDelegate = AppDelegate()

  static func main() {
    let app = NSApplication.shared
    app.delegate = sharedDelegate
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    WidgetRegistry.shared.registerAllWidgets()
    let contentView = StatusBarView()

    // Create initial window
    statusBarWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    statusBarWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
    statusBarWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    statusBarWindow.backgroundColor = .clear
    statusBarWindow.hasShadow = false
    statusBarWindow.isOpaque = false

    let hostingController = NSHostingController(rootView: contentView)
    statusBarWindow.contentView = hostingController.view

    // Calculate initial window position
    updateWindowPosition()

    statusBarWindow.makeKeyAndOrderFront(nil)
    statusBarWindow.orderFrontRegardless()
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
  }

  // Reposition window forcibly to the top of the screen
  @objc func updateWindowPosition() {
    // Run asynchronously to wait for system screen info updates to complete
    DispatchQueue.main.async {
      guard let screen = NSScreen.screens.first else { return }
      let screenRect = screen.frame

      let windowRect = NSRect(
        x: screenRect.minX,
        y: screenRect.maxY - self.barHeight,
        width: screenRect.width,
        height: self.barHeight
      )

      // Snap immediately to the correct position and size without animation
      self.statusBarWindow.setFrame(windowRect, display: true)
    }
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

  @State private var isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()

  var body: some View {
    let currentLayout: DisplayLayoutConfig =
      isBuiltInDisplay
      ? ConfigManager.shared.currentConfig.builtInDisplay
      : ConfigManager.shared.currentConfig.externalDisplay

    ZStack(alignment: .top) {
      // Left widget group
      HStack(alignment: .top, spacing: 8) {
        ForEach(currentLayout.left, id: \.id) { instance in
          if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
            factory.makeView(config: instance.config)
          }
        }

        // In built-in display mode, place island from right of audio widget toward center camera
        if isBuiltInDisplay {
          Color.clear
            .frame(width: 32, height: 32)
            .overlay(
              KamidanaIsland(centerWidgets: currentLayout.center)
                .fixedSize(), alignment: .topLeading
            )
            .zIndex(100)
        }
      }
      .frame(height: 40)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 10)
      .padding(.top, 5)

      // Right widget group
      HStack(
        alignment: .top,
        spacing: 8,
        content: {
          ForEach(currentLayout.right, id: \.id) { instance in
            if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
              factory.makeView(config: instance.config)
            }
          }
        }
      )
      .frame(height: 40)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.trailing, 10)
      .padding(.top, 5)

      // In external display mode, place in the top center of the screen
      if !isBuiltInDisplay {
        KamidanaIsland(centerWidgets: currentLayout.center)
          .fixedSize()
          .padding(.top, 7)
          .zIndex(100)
      }
    }
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
      isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
    }
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSApplication.didChangeScreenParametersNotification)
    ) { _ in
      // System screen info (NSScreen.screens) might not be updated yet right after receiving the notification,
      // so evaluate asynchronously with a slight delay
      DispatchQueue.main.async {
        isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
        // print("Updated isBuiltInDisplay: \(isBuiltInDisplay)")
      }
    }
  }
}
