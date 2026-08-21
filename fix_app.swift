import Foundation

let path = "Sources/KamidanaApp/KamidanaApp.swift"
var text = try String(contentsOfFile: path, encoding: .utf8)

// Replace AppDelegate
let appDelegateRegex = try NSRegularExpression(pattern: "class AppDelegate: NSObject, NSApplicationDelegate \\{.*?\\n\\}", options: [.dotMatchesLineSeparators])
let replacement = """
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
    let isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
    ConfigManager.shared.activateConfiguration(isBuiltIn: isBuiltInDisplay)
    let contentView = StatusBarView()

    // Create initial window
    statusBarWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // statusBarWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
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
"""
text = appDelegateRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)

// Replace let currentScreen: NSScreen with @State private var currentScreen: NSScreen = NSScreen.screens.first ?? NSScreen.main!
text = text.replacingOccurrences(of: "  let currentScreen: NSScreen", with: "  @State private var currentScreen: NSScreen = NSScreen.screens.first ?? NSScreen.main!")

// Add back the .onReceive logic at the end of StatusBarView
let onAppearRegex = try NSRegularExpression(pattern: "    \\.onAppear \\{\\n      matrix\\.startMonitoring\\(\\)\\n      localSend\\.scanNetwork\\(\\)\\n    \\}", options: [.dotMatchesLineSeparators])
let onAppearReplacement = """
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
"""
text = onAppearRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: onAppearReplacement)

try text.write(toFile: path, atomically: true, encoding: .utf8)
