import XCTest

@testable import Kamidana

final class KamidanaConfigurationV1Tests: XCTestCase {
  private let validYAML = """
    global:
      background_mode: per_section
      hide_in_fullscreen: true
      bar_padding: 4
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
      popup_style:
        background: "#121212"
        corner_radius: 14
        border:
          width: 2
          color: "#333333"
    left:
      background_mode: per_widget
      style:
        spacing: 4
      popup_style:
        corner_radius: 16
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
        - id: network-main
          type: network
          motion: static
          format: "{connection_icon} {upload} {upload_icon} {download} {download_icon}"
          popup_style:
            corner_radius: 18
    center:
      activate: hover
      center_default: music-main
      widgets:
        - id: music-main
          type: music
          compact_format: "music {title}"
          format: "music {title}"
          part_styles:
            media:
              color: "#ffffff"
            media_slider:
              opacity: 0.8
        - id: terminal-main
          type: btop
          compact_format: "btop"
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
    XCTAssertEqual(configuration.left.widgets[1].motion, .static)
    XCTAssertEqual(configuration.global.backgroundMode, .perSection)
    XCTAssertTrue(configuration.global.hideInFullscreen)
    XCTAssertEqual(configuration.global.barPadding.top, 4)
    XCTAssertEqual(configuration.global.barPadding.leading, 4)
    XCTAssertEqual(configuration.global.popupStyle?.cornerRadius, 14)
    XCTAssertEqual(configuration.global.popupStyle?.border?.width, 2)
    XCTAssertEqual(configuration.left.backgroundMode, .perWidget)
    XCTAssertEqual(configuration.left.popupStyle?.cornerRadius, 16)
    XCTAssertEqual(configuration.left.widgets[1].popupStyle?.cornerRadius, 18)
    XCTAssertEqual(configuration.center.centerDefault, "music-main")
    XCTAssertEqual(configuration.center.activate, .hover)
    XCTAssertEqual(configuration.center.widgets.count, 2)
    XCTAssertEqual(configuration.left.widgets[0].actionChildren[0].id, "sleep-action")
    XCTAssertEqual(configuration.center.widgets[0].partStyles["media"]?.color, "#ffffff")
  }

  func testRejectsInvalidPopupStyleNumericValue() {
    let yaml = validYAML.replacingOccurrences(
      of: "      popup_style:\n        corner_radius: 18\n",
      with: "      popup_style:\n        corner_radius: -1\n"
    )

    assertError(
      yaml,
      matches: {
        if case .invalidStyle(let path, let reason) = $0 {
          return path.contains("popup_style") && reason.contains("corner_radius")
        }
        return false
      }
    )
  }

  func testDecodesCombinedMonitorProfiles() throws {
    let yaml = """
      global:
        bar_padding:
          top: 3
          leading: 5
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

    let profiles = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: yaml)

    XCTAssertEqual(profiles.external.center.centerDefault, "external-clock")
    XCTAssertEqual(profiles.builtIn.center.centerDefault, "built-in-clock")
    XCTAssertEqual(profiles.external.global.barPadding.top, 3)
    XCTAssertEqual(profiles.external.global.barPadding.leading, 5)
    XCTAssertEqual(profiles.builtIn.global.barPadding.top, 3)
  }

  func testCombinedMonitorProfilesRequireBuiltInAndExternalSections() {
    let yaml = """
      external:
        center:
          center_default: external-clock
          widgets:
            - id: external-clock
              type: clock
              compact_format: "{time}"
      """

    XCTAssertThrowsError(try KamidanaMonitorConfigurationV1Decoder.decode(yaml: yaml))
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

  func testRejectsIconPropertyOnRegularWidget() {
    let yaml = validYAML.replacingOccurrences(
      of: "      format: \"{connection_icon} {upload} {upload_icon} {download} {download_icon}\"\n",
      with:
        "      format: \"{connection_icon} {upload} {upload_icon} {download} {download_icon}\"\n      icon: \"network\"\n"
    )
    assertError(
      yaml,
      matches: {
        if case .invalidWidget(_, let reason) = $0 {
          return reason.contains("include Nerd Font icons in format")
        }
        return false
      }
    )
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

  func testRejectsCenterDefaultWithoutAnyNormalFormat() {
    let yaml =
      validYAML
      .replacingOccurrences(of: "      compact_format: \"music {title}\"\n", with: "")
      .replacingOccurrences(of: "      format: \"music {title}\"\n", with: "")
    assertError(
      yaml,
      matches: {
        if case .centerDefaultRequiresCompactFormat("music-main") = $0 { return true }
        return false
      })
  }

  func testDecodesStandaloneAndCenterMusicStates() throws {
    let yaml = """
      left:
        widgets:
          - id: music-left
            type: music
            format: "{artwork} {title}"
            format_on_action: "{artwork} {slider}"
            slider_change: "#111111"
            slider_pause: "#222222"
            slider_bar: "#333333"
            extend: right
            artwork_spin: 4
      center:
        center_default: music-center
        widgets:
          - id: music-center
            type: music
            normal:
              format: "{artwork} {title}"
              format_on_action: "{artwork} {slider}"
              slider_change: "#444444"
              slider_pause: "#555555"
              slider_bar: "#666666"
              extend: left
              artwork_spin: 3
            on_action:
              format: "{title} - {album}"
              artwork_spin: 0
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let standalone = try XCTUnwrap(configuration.left.widgets.first)
    XCTAssertEqual(standalone.formatOnAction, "{artwork} {slider}")
    XCTAssertEqual(standalone.extend, .right)
    XCTAssertEqual(standalone.sliderBar, "#333333")

    let center = try XCTUnwrap(configuration.center.widgets.first)
    XCTAssertEqual(center.normal?.format, "{artwork} {title}")
    XCTAssertEqual(center.normal?.extend, .left)
    XCTAssertEqual(center.onAction?.format, "{title} - {album}")
    XCTAssertEqual(center.onAction?.artworkSpin, 0)
  }

  func testRejectsNegativeArtworkSpinDuration() {
    let yaml = """
      left:
        widgets:
          - id: music-left
            type: music
            format: "{artwork} {title}"
            artwork_spin: -1
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    assertError(
      yaml,
      matches: {
        if case .invalidWidget(_, let reason) = $0 {
          return reason.contains("artwork_spin must be zero or a positive number of seconds")
        }
        return false
      }
    )
  }

  func testRejectsBooleanArtworkSpinValue() {
    let yaml = """
      center:
        center_default: music
        widgets:
          - id: music
            type: music
            normal:
              format: "{artwork} {title}"
              artwork_spin: true
      """

    assertError(
      yaml,
      matches: {
        if case .yamlDecoding = $0 { return true }
        return false
      }
    )
  }

  func testRejectsBtopOutsideCenter() {
    let yaml =
      validYAML
      .replacingOccurrences(
        of: "    - id: terminal-main\n      type: btop\n      compact_format: \"btop\"\n",
        with: ""
      )
      .replacingOccurrences(
        of: "    - id: custom-main\n",
        with:
          "    - id: btop-right\n      type: btop\n      compact_format: \"btop\"\n    - id: custom-main\n"
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
      of: "      format: \"music {title}\"\n",
      with:
        "      format: \"music {title}\"\n      tooltip: true\n      tooltip_format: \"music\"\n",
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
    let yaml = validYAML.replacingOccurrences(of: "type: network", with: "type: not-a-widget")
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
      of: "      type: network\n",
      with: "      type: network\n      command: \"uname\"\n"
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
        "bluetooth", "custom", "widget-folder", "system-action", "btop",
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
