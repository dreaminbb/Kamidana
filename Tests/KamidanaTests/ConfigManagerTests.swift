import XCTest

@testable import Kamidana

final class ConfigManagerTests: XCTestCase {

  var manager: ConfigManager!
  var defaultHomeURL: URL!

  override func setUp() {
    super.setUp()
    manager = ConfigManager.shared
    defaultHomeURL = FileManager.default.homeDirectoryForCurrentUser
  }

  override func tearDown() {
    manager = nil
    super.tearDown()
  }

  /// Tests resolving the fixed config directory (~/.config/kamidana)
  func testResolveConfigDirectory() {
    let expectedURL =
      defaultHomeURL
      .appendingPathComponent(".config")
      .appendingPathComponent("kamidana")

    let actualURL = manager.resolveConfigDirectory()
    print("[Test: Fixed Config Dir] Resolved Path: \(actualURL.path)")

    XCTAssertEqual(
      actualURL.path, expectedURL.path, "Config directory must be fixed to ~/.config/kamidana")
  }

  /// Tests custom homeDirectory injection
  func testResolveConfigDirectory_CustomHome() {
    let mockHome = URL(fileURLWithPath: "/Users/testuser")
    let expectedURL =
      mockHome
      .appendingPathComponent(".config")
      .appendingPathComponent("kamidana")

    let actualURL = manager.resolveConfigDirectory(homeDirectory: mockHome)
    print("[Test: Custom Home Config Dir] Resolved Path: \(actualURL.path)")

    XCTAssertEqual(
      actualURL.path, expectedURL.path,
      "Config directory for custom home should be /Users/testuser/.config/kamidana")
  }

  /// Tests resolving the fixed config.yaml file URL (~/.config/kamidana/config.yaml)
  func testResolveConfigFileURL() {
    let expectedFileURL =
      defaultHomeURL
      .appendingPathComponent(".config")
      .appendingPathComponent("kamidana")
      .appendingPathComponent("config.yaml")

    let actualFileURL = manager.resolveConfigFileURL()
    print("[Test: Fixed config.yaml File URL] Resolved Path: \(actualFileURL.path)")

    XCTAssertEqual(
      actualFileURL.path, expectedFileURL.path,
      "Config file URL must be fixed to ~/.config/kamidana/config.yaml")
  }

  func testResolveLegacyBuiltInConfigFileURL() {
    let expectedFileURL =
      defaultHomeURL
      .appendingPathComponent(".config")
      .appendingPathComponent("kamidana")
      .appendingPathComponent("built_in_monitor.yaml")

    XCTAssertEqual(
      manager.resolveBuiltInConfigFileURL().path,
      expectedFileURL.path,
      "Legacy built-in config file URL must remain available for migration"
    )
  }

  func testWindowRectAppliesMonitorPaddingToTheBarWindow() {
    let screenRect = NSRect(x: 100, y: 200, width: 1400, height: 900)
    let rect = AppDelegate.windowRect(
      for: screenRect,
      barHeight: 600,
      barPadding: KamidanaInsets(top: 12, bottom: 5, leading: 10, trailing: 20)
    )

    XCTAssertEqual(rect.origin.x, 110)
    XCTAssertEqual(rect.origin.y, 505)
    XCTAssertEqual(rect.size.width, 1370)
    XCTAssertEqual(rect.size.height, 583)
  }

  /// Tests fetchUserConfigPath() returns the fixed directory path string
  func testFetchUserConfigPath() {
    let pathString = manager.fetchUserConfigPath()
    print("[Test: fetchUserConfigPath()] Returned Path: \(pathString)")

    XCTAssertFalse(pathString.isEmpty, "Config path string should not be empty")
    XCTAssertTrue(
      pathString.hasSuffix(".config/kamidana"), "Config path string must end with .config/kamidana")
  }

  func testLoadConfigLog() {
    manager.loadConfig()
    print(manager.currentConfig)
  }

  func testLoadConfigReadsCombinedMonitorProfiles() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let yaml = """
      external:
        center:
          center_default: regular-clock
          widgets:
            - id: regular-clock
              type: clock
              compact_format: "regular {time}"
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "built-in {time}"
      """
    try yaml.write(
      to: manager.resolveConfigFileURL(homeDirectory: temporaryHome),
      atomically: true,
      encoding: .utf8
    )
    let staleLegacyYAML = """
      center:
        center_default: stale-clock
        widgets:
          - id: stale-clock
            type: clock
            compact_format: "stale {time}"
      """
    try staleLegacyYAML.write(
      to: manager.resolveBuiltInConfigFileURL(homeDirectory: temporaryHome),
      atomically: true,
      encoding: .utf8
    )

    manager.loadConfig(homeDirectory: temporaryHome)

    XCTAssertEqual(
      manager.configurationForDisplay(isBuiltIn: false)?.center.centerDefault,
      "regular-clock"
    )
    XCTAssertEqual(
      manager.configurationForDisplay(isBuiltIn: true)?.center.centerDefault,
      "built-in-clock"
    )
  }

  func testLoadConfigFallsBackToRegularFileForBuiltInDisplay() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let yaml = """
      center:
        center_default: shared-clock
        widgets:
          - id: shared-clock
            type: clock
            compact_format: "{time}"
      """
    try yaml.write(
      to: manager.resolveConfigFileURL(homeDirectory: temporaryHome),
      atomically: true,
      encoding: .utf8
    )

    manager.loadConfig(homeDirectory: temporaryHome)

    XCTAssertEqual(
      manager.configurationForDisplay(isBuiltIn: true),
      manager.configurationForDisplay(isBuiltIn: false)
    )
  }
}
