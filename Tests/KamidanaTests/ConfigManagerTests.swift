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
}
