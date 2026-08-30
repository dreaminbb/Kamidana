import XCTest

@testable import KamidanaApp

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

  func testDefaultLayoutUsesMonitorProfileSchemaAndClearsOnLegacyReload() throws {
    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let defaultLayoutYAML = """
      global:
        display_targets:
          - kind: all
      default_layout:
        center:
          center_default: default-clock
          widgets:
            - id: default-clock
              type: clock
              compact_format: "{time}"
      """
    let legacyYAML = """
      center:
        center_default: legacy-clock
        widgets:
          - id: legacy-clock
            type: clock
            compact_format: "{time}"
      """

    try manager.applyV1Configuration(yaml: defaultLayoutYAML)

    XCTAssertEqual(
      manager.monitorProfiles?.displays["default_layout"]?.center.centerDefault,
      "default-clock"
    )
    XCTAssertEqual(manager.globalV1Config.displayTargets, [KamidanaDisplayTarget(kind: .all)])

    try manager.applyV1Configurations(regularYAML: legacyYAML, builtInYAML: legacyYAML)

    XCTAssertNil(manager.monitorProfiles)
    XCTAssertEqual(manager.currentV1Config?.center.centerDefault, "legacy-clock")
  }

  func testUpdateLaunchAtLoginPreservesContentsWhenGlobalIsAbsent() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let configURL = manager.resolveConfigFileURL(homeDirectory: temporaryHome)
    let yaml = """
      # Keep this document header.
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"

      # Keep this separation between display profiles.
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "{time}"
      """
    try yaml.write(to: configURL, atomically: true, encoding: .utf8)

    try manager.updateLaunchAtLogin(isEnabled: true, homeDirectory: temporaryHome)

    let expectedYAML = "global:\n  launch_at_login: true\n\n" + yaml
    XCTAssertEqual(try Data(contentsOf: configURL), Data(expectedYAML.utf8))
    let updatedYAML = try String(contentsOf: configURL, encoding: .utf8)
    let profiles = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: updatedYAML)
    XCTAssertTrue(profiles.global.launchAtLogin)
    XCTAssertEqual(profiles.displays["external"]?.center.centerDefault, "external-clock")
  }

  func testUpdateLaunchAtLoginInsertsIntoExistingGlobalWithoutChangingContents() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let configURL = manager.resolveConfigFileURL(homeDirectory: temporaryHome)
    let yaml = """
      global:
        # Keep global settings in this order.
        hide_in_fullscreen: true

        bar_padding:
          top: 0
      # Keep this top-level comment.
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "{time}"
      """
    try yaml.write(to: configURL, atomically: true, encoding: .utf8)

    try manager.updateLaunchAtLogin(isEnabled: false, homeDirectory: temporaryHome)

    let expectedYAML = """
      global:
        # Keep global settings in this order.
        hide_in_fullscreen: true

        bar_padding:
          top: 0
        launch_at_login: false
      # Keep this top-level comment.
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "{time}"
      """
    XCTAssertEqual(try Data(contentsOf: configURL), Data(expectedYAML.utf8))
    let updatedYAML = try String(contentsOf: configURL, encoding: .utf8)
    let profiles = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: updatedYAML)
    XCTAssertFalse(profiles.global.launchAtLogin)
    XCTAssertTrue(profiles.global.hideInFullscreen)
  }

  func testUpdateLaunchAtLoginPreservesDirectScalarCommentsAndOrdering() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let configURL = manager.resolveConfigFileURL(homeDirectory: temporaryHome)
    let yaml = """
      # Do not reorder this document.
      global:
        hide_in_fullscreen: true

        launch_at_login: false  # Preserve this note.
        bar_padding:
          top: 0
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "{time}"
      """
    try yaml.write(to: configURL, atomically: true, encoding: .utf8)

    try manager.updateLaunchAtLogin(isEnabled: true, homeDirectory: temporaryHome)

    let expectedYAML = yaml.replacingOccurrences(
      of: "launch_at_login: false",
      with: "launch_at_login: true"
    )
    XCTAssertEqual(try Data(contentsOf: configURL), Data(expectedYAML.utf8))
    let profiles = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: expectedYAML)
    XCTAssertTrue(profiles.global.launchAtLogin)
  }

  func testUpdateLaunchAtLoginRejectsFlowStyleGlobalWithoutChangingContents() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let configURL = manager.resolveConfigFileURL(homeDirectory: temporaryHome)
    let yaml = """
      global: { hide_in_fullscreen: true, launch_at_login: false }
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "{time}"
      """
    try yaml.write(to: configURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(
      try manager.updateLaunchAtLogin(isEnabled: true, homeDirectory: temporaryHome)
    ) { error in
      guard let configError = error as? ConfigManagerError,
        case .launchAtLoginRequiresBlockGlobal = configError
      else {
        return XCTFail("Expected a block-global configuration error, got \(error)")
      }
    }
    XCTAssertEqual(try Data(contentsOf: configURL), Data(yaml.utf8))
  }

  func testUpdateLaunchAtLoginRetainsInvalidYAMLContents() throws {
    let temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryHome) }

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let configDirectory = manager.resolveConfigDirectory(homeDirectory: temporaryHome)
    try FileManager.default.createDirectory(
      at: configDirectory,
      withIntermediateDirectories: true
    )
    let configURL = manager.resolveConfigFileURL(homeDirectory: temporaryHome)
    let invalidYAML = """
      global:
        unsupported_setting: true
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"
      built_in:
        center:
          center_default: built-in-clock
          widgets:
            - id: built-in-clock
              type: clock
              compact_format: "{time}"
      """
    try invalidYAML.write(to: configURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(
      try manager.updateLaunchAtLogin(isEnabled: true, homeDirectory: temporaryHome)
    )
    XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), invalidYAML)
  }
}
