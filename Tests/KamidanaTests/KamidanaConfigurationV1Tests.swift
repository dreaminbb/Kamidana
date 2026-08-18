import XCTest

@testable import Kamidana

final class KamidanaConfigurationV1Tests: XCTestCase {
  private let validYAML = """
    global:
      background_mode: per_section
      hide_in_fullscreen: true
      style:
        background: "#111111"
        color: "#eeeeee"
        opacity: 0.9
        padding: 6
        corner_radius: 8
        material: ultra_thin
        animation:
          preset: spring
          duration_seconds: 0.25
          damping: 0.7
    left:
      background_mode: per_widget
      style:
        spacing: 4
      widgets:
        - id: actions
          type: system-action
          icon: "power"
          folded_icon: "power-folded"
          children:
            - id: sleep-action
              type: sleep
              format: "{icon} {name}"
              icon: "sleep"
              style:
                icon_color: "#aaaaaa"
        - id: wifi-main
          type: wifi
          format: "{icon} {ssid}"
          icon: "wifi"
    center:
      activate: hover
      center_default: music-main
      widgets:
        - id: music-main
          type: music
          compact_format: "{icon} {title}"
          format: "{icon} {title}"
          part_styles:
            media:
              color: "#ffffff"
            media_slider:
              opacity: 0.8
        - id: terminal-main
          type: btop
          compact_format: "{icon}"
    right:
      widgets:
        - id: cpu-main
          type: cpu
          tooltip: true
          tooltip_format: "{usage}%"
          interval: 2
        - id: custom-main
          type: custom
          command: "uname"
          arguments: ["-a"]
    """

  func testDecodesValidRepresentativeConfiguration() throws {
    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: validYAML)
    XCTAssertEqual(configuration.global.backgroundMode, .perSection)
    XCTAssertTrue(configuration.global.hideInFullscreen)
    XCTAssertEqual(configuration.left.backgroundMode, .perWidget)
    XCTAssertEqual(configuration.center.centerDefault, "music-main")
    XCTAssertEqual(configuration.center.activate, .hover)
    XCTAssertEqual(configuration.center.widgets.count, 2)
    XCTAssertEqual(configuration.left.widgets[0].actionChildren[0].id, "sleep-action")
    XCTAssertEqual(configuration.center.widgets[0].partStyles["media"]?.color, "#ffffff")
  }

  func testRejectsDuplicateIDsIncludingActionChildren() {
    let yaml = validYAML.replacingOccurrences(of: "id: sleep-action", with: "id: cpu-main")
    assertError(
      yaml,
      matches: {
        if case .duplicateID("cpu-main") = $0 { return true }
        return false
      })
  }

  func testRejectsMissingOrInvalidCenterDefault() {
    let missing = validYAML.replacingOccurrences(
      of: "center_default: music-main\n", with: "center_default: missing\n")
    assertError(
      missing,
      matches: {
        if case .invalidCenterDefault("missing") = $0 { return true }
        return false
      })
  }

  func testRejectsCenterDefaultWithoutCompactFormat() {
    let yaml = validYAML.replacingOccurrences(
      of: "      compact_format: \"{icon} {title}\"\n", with: "")
    assertError(
      yaml,
      matches: {
        if case .centerDefaultRequiresCompactFormat("music-main") = $0 { return true }
        return false
      })
  }

  func testRejectsBtopOutsideCenter() {
    let yaml =
      validYAML
      .replacingOccurrences(
        of: "    - id: terminal-main\n      type: btop\n      compact_format: \"{icon}\"\n",
        with: ""
      )
      .replacingOccurrences(
        of: "    - id: custom-main\n",
        with:
          "    - id: btop-right\n      type: btop\n      compact_format: \"{icon}\"\n    - id: custom-main\n"
      )
    assertError(
      yaml,
      matches: {
        if case .btopMustBeInCenter("btop-right") = $0 { return true }
        return false
      })
  }

  func testRejectsTooltipOnMusic() {
    let yaml = validYAML.replacingOccurrences(
      of: "      format: \"{icon} {title}\"\n",
      with:
        "      format: \"{icon} {title}\"\n      tooltip: true\n      tooltip_format: \"music\"\n",
      options: .caseInsensitive)
    assertError(
      yaml,
      matches: {
        if case .tooltipNotAllowed = $0 { return true }
        return false
      })
  }

  func testRejectsEmptyCustomCommand() {
    let yaml = validYAML.replacingOccurrences(of: "command: \"uname\"", with: "command: \"   \"")
    assertError(
      yaml,
      matches: {
        if case .emptyCustomCommand = $0 { return true }
        return false
      })
  }

  func testRejectsInvalidStyleNumericValue() {
    let yaml = validYAML.replacingOccurrences(of: "opacity: 0.9", with: "opacity: 1.5")
    assertError(
      yaml,
      matches: {
        if case .invalidStyle = $0 { return true }
        return false
      })
  }

  func testRejectsUnsupportedWidgetType() {
    let yaml = validYAML.replacingOccurrences(of: "type: wifi", with: "type: not-a-widget")
    assertError(
      yaml,
      matches: {
        if case .unsupportedWidgetType("not-a-widget") = $0 { return true }
        return false
      })
  }

  func testDefaultsOmittedOuterSectionsAndGlobalSettings() throws {
    let yaml = """
      center:
        center_default: clock-main
        widgets:
          - id: clock-main
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    XCTAssertEqual(configuration.global.backgroundMode, .singleBar)
    XCTAssertFalse(configuration.global.hideInFullscreen)
    XCTAssertTrue(configuration.left.widgets.isEmpty)
    XCTAssertTrue(configuration.right.widgets.isEmpty)
  }

  func testDecodesWidgetFolderDirectionAndVolumeDefaults() throws {
    let yaml = """
      left:
        widgets:
          - id: utilities
            type: widget-folder
            direction: right
            icon: "folder"
            folded_icon: "folder-closed"
            widgets:
              - id: volume-main
                type: volume
      center:
        center_default: clock-main
        widgets:
          - id: clock-main
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let folder = try XCTUnwrap(configuration.left.widgets.first)
    XCTAssertEqual(folder.direction, .right)
    XCTAssertEqual(folder.widgets.first?.inputManagement, true)
    XCTAssertEqual(folder.widgets.first?.outputManagement, true)
  }

  func testRejectsNestedCenterDefault() {
    let yaml = """
      center:
        center_default: nested-clock
        widgets:
          - id: folder-main
            type: widget-folder
            compact_format: "{icon}"
            widgets:
              - id: nested-clock
                type: clock
                compact_format: "{time}"
      """

    assertError(
      yaml,
      matches: {
        if case .invalidCenterDefault("nested-clock") = $0 { return true }
        return false
      })
  }

  func testRejectsNestedBtop() {
    let yaml = """
      center:
        center_default: folder-main
        widgets:
          - id: folder-main
            type: widget-folder
            compact_format: "{icon}"
            widgets:
              - id: nested-btop
                type: btop
      """

    assertError(
      yaml,
      matches: {
        if case .btopMustBeInCenter("nested-btop") = $0 { return true }
        return false
      })
  }

  func testRejectsKindSpecificFieldsOnWrongWidget() {
    let yaml = validYAML.replacingOccurrences(
      of: "      type: wifi\n",
      with: "      type: wifi\n      command: \"uname\"\n"
    )
    assertError(
      yaml,
      matches: {
        if case .invalidWidget = $0 { return true }
        return false
      })
  }

  func testRejectsEmptyWidgetFolder() {
    let yaml = """
      center:
        center_default: folder-main
        widgets:
          - id: folder-main
            type: widget-folder
            compact_format: "{icon}"
      """

    assertError(
      yaml,
      matches: {
        if case .invalidWidget = $0 { return true }
        return false
      })
  }

  func testRejectsInvalidInterval() {
    let yaml = validYAML.replacingOccurrences(of: "interval: 2", with: "interval: 0")
    assertError(
      yaml,
      matches: {
        if case .invalidWidget = $0 { return true }
        return false
      })
  }

  func testDefaultsWidgetFolderDirectionToBelow() throws {
    let yaml = """
      left:
        widgets:
          - id: simple-folder
            type: widget-folder
            widgets:
              - id: clock-child
                type: clock
      center:
        center_default: clock-main
        widgets:
          - id: clock-main
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    XCTAssertEqual(configuration.left.widgets.first?.direction, .below)
  }

  func testRejectsExpandingWidgetInsideBelowFolder() {
    let yaml = """
      left:
        widgets:
          - id: invalid-folder
            type: widget-folder
            widgets:
              - id: nested-music
                type: music
      center:
        center_default: clock-main
        widgets:
          - id: clock-main
            type: clock
            compact_format: "{time}"
      """

    assertError(
      yaml,
      matches: {
        if case .invalidWidget(_, let reason) = $0 {
          return reason.contains("nested-music")
        }
        return false
      })
  }

  func testContainsExactlyThePublicWidgetTypes() {
    XCTAssertEqual(
      Set(KamidanaWidgetKind.allCases.map(\.rawValue)),
      Set([
        "music", "volume", "cpu", "gpu", "memory", "network", "disk", "battery", "clock",
        "wifi", "bluetooth", "custom", "widget-folder", "system-action", "btop",
      ])
    )
  }

  func testRejectsUnknownConfigurationKey() {
    let yaml = validYAML.replacingOccurrences(
      of: "color: \"#eeeeee\"",
      with: "colour: \"#eeeeee\""
    )

    assertError(
      yaml,
      matches: {
        if case .yamlDecoding(let message) = $0 {
          return message.contains("Unknown configuration key 'colour'")
        }
        return false
      })
  }

  private func assertError(
    _ yaml: String,
    matches predicate: (KamidanaConfigurationV1Error) -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(
      try KamidanaConfigurationV1Decoder.decode(yaml: yaml), file: file, line: line
    ) { error in
      guard let typedError = error as? KamidanaConfigurationV1Error else {
        return XCTFail("Unexpected error: \(error)", file: file, line: line)
      }
      XCTAssertTrue(predicate(typedError), typedError.description, file: file, line: line)
    }
  }
}
