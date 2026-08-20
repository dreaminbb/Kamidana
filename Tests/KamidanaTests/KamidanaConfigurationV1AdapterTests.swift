import XCTest

@testable import Kamidana

final class KamidanaConfigurationV1AdapterTests: XCTestCase {
  func testAdapterPreservesSectionAndWidgetStyleAndCenterDefaultOrder() throws {
    let yaml = """
      global:
        style:
          background: "#101010"
          color: "#eeeeee"
        bar_padding:
          top: 4
          leading: 6
          trailing: 6
        popup_style:
          background: "#202020"
          corner_radius: 12
      left:
        style:
          padding: 9
        popup_style:
          corner_radius: 16
        widgets:
          - id: left-cpu
            type: cpu
            format: "󰍛 {usage}%"
            style:
              icon_color: "#ff0000"
            popup_style:
              corner_radius: 18
              border:
                width: 2
                color: "#00ff00"
      center:
        center_default: music
        widgets:
          - id: secondary
            type: clock
            compact_format: "{time}"
          - id: music
            type: music
            compact_format: "{icon}"
      right:
        style:
          corner_radius: 20
        widgets:
          - id: custom
            type: custom
            command: "printf"
            arguments: ["ok"]
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let legacy = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)

    XCTAssertEqual(legacy.colors.background, "#101010")
    XCTAssertEqual(legacy.externalDisplay.center.first?.typeID, "music")
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1Style?.iconColor, "#ff0000")
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1Style?.color, "#eeeeee")
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1Format, "󰍛 {usage}%")
    XCTAssertEqual(legacy.externalDisplay.right.first?.v1Style?.cornerRadius, 20)
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1Style?.padding?.top, 9)
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1PopupStyle?.background, "#202020")
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1PopupStyle?.cornerRadius, 18)
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1PopupStyle?.border?.width, 2)
    XCTAssertEqual(legacy.externalDisplay.left.first?.v1PopupStyle?.border?.color, "#00ff00")
    XCTAssertEqual(legacy.externalDisplay.barPadding.top, 4)
    XCTAssertEqual(legacy.externalDisplay.barPadding.leading, 6)
    XCTAssertEqual(legacy.externalDisplay.barPadding.trailing, 6)
  }

  func testExecutableResolverUsesOnlyPathEntries() {
    XCTAssertEqual(
      KamidanaExecutableResolver.resolve(
        "kamidana-command-that-does-not-exist",
        environment: ["PATH": "/bin"]
      ),
      nil
    )
  }

  func testAdapterPropagatesSystemActionChildStyle() throws {
    let yaml = """
      left:
        widgets:
          - id: actions
            type: system-action
            children:
              - id: sleep
                type: sleep
                format: "Sleep"
                icon: "sleep"
                style:
                  color: "#123456"
                  icon_color: "#654321"
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let runtime = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)
    let folder = try XCTUnwrap(runtime.externalDisplay.left.first?.config as? WidgetFolderConfig)
    XCTAssertEqual(folder.widgets.first?.v1Style?.color, "#123456")
    XCTAssertEqual(folder.widgets.first?.v1Style?.iconColor, "#654321")
  }

  func testAdapterDisablesVolumeInputManagement() throws {
    let yaml = """
      left:
        widgets:
          - id: output-only
            type: volume
            format: "󰕾 {volume}%"
            input_management: false
            output_management: true
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let runtime = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)
    let audio = try XCTUnwrap(runtime.externalDisplay.left.first?.config as? AudioWidgetConfig)

    XCTAssertEqual(audio.inputManagement, false)
    XCTAssertFalse(audio.showsInputManagement)
  }

  func testAdapterDisablesVolumeOutputManagement() throws {
    let yaml = """
      left:
        widgets:
          - id: input-only
            type: volume
            format: "{volume}%"
            input_management: true
            output_management: false
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let runtime = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)
    let audio = try XCTUnwrap(runtime.externalDisplay.left.first?.config as? AudioWidgetConfig)

    XCTAssertEqual(audio.outputManagement, false)
    XCTAssertTrue(audio.showsInputManagement)
    XCTAssertFalse(audio.showsOutputManagement)
  }

  func testStyleStateOverridesBaseStyle() {
    let base = KamidanaStyle(
      background: "#111111",
      color: "#eeeeee",
      states: ["hover": KamidanaStyle(background: "#222222")]
    )

    let hover = KamidanaConfigurationV1Adapter.style(base, applyingState: "hover")
    XCTAssertEqual(hover.background, "#222222")
    XCTAssertEqual(hover.color, "#eeeeee")
  }

  func testAdapterPropagatesWidgetActivationOverSectionActivation() throws {
    let yaml = """
      right:
        activate: click
        widgets:
          - id: cpu
            type: cpu
            activate: hover
            motion: static
          - id: gpu
            type: gpu
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let runtime = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)

    XCTAssertEqual(runtime.externalDisplay.right[0].v1Activate, .hover)
    XCTAssertEqual(runtime.externalDisplay.right[1].v1Activate, .click)
    XCTAssertEqual(runtime.externalDisplay.right[0].v1Motion, .static)
    XCTAssertEqual(runtime.externalDisplay.right[1].v1Motion, .dynamic)
  }

  func testAdapterBuildsPlacementSpecificMusicConfiguration() throws {
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
            artwork_spin: 0
      center:
        center_default: music-center
        widgets:
          - id: music-center
            type: music
            normal:
              format: "{artwork} {title}"
              format_on_action: "{artwork} {slider}"
              extend: right
              artwork_spin: 4
            on_action:
              format: "{title} - {album}"
              artwork_spin: 0
      right:
        widgets:
          - id: music-right
            type: music
            format: "{artwork} {title}"
      """

    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let runtime = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)
    let left = try XCTUnwrap(runtime.externalDisplay.left.first?.config as? MusicWidgetConfig)
    let center = try XCTUnwrap(runtime.externalDisplay.center.first?.config as? MusicWidgetConfig)
    let right = try XCTUnwrap(runtime.externalDisplay.right.first?.config as? MusicWidgetConfig)

    XCTAssertEqual(left.placement, .standalone)
    XCTAssertEqual(left.extend, .right)
    XCTAssertEqual(left.sliderChangeColor, "#111111")
    XCTAssertEqual(left.artworkSpinDuration, 0)
    XCTAssertEqual(center.placement, .center)
    XCTAssertEqual(center.actionMetadataFormat, "{title} - {album}")
    XCTAssertEqual(center.artworkSpinDuration, 4)
    XCTAssertEqual(center.actionArtworkSpinDuration, 0)
    XCTAssertEqual(right.extend, .left)
  }

  func testConfigManagerBuildsLayoutsFromCombinedMonitorProfiles() throws {
    let yaml = """
      external:
        global:
          bar_padding:
            top: 1
          style:
            color: "#111111"
        left:
          widgets:
            - id: external-music
              type: music
              format: "{artwork} {title}"
        center:
          center_default: external-center
          widgets:
            - id: external-center
              type: music
              normal:
                format: "{artwork} {title}"
        right:
          widgets:
            - id: external-cpu
              type: cpu
              format: "󰍛 {usage}%"
      built_in:
        global:
          bar_padding:
            top: 2
          style:
            color: "#222222"
        left:
          widgets:
            - id: built-in-volume
              type: volume
              format: "󰕾 {volume}%"
        center:
          center_default: built-in-center
          widgets:
            - id: built-in-center
              type: clock
              compact_format: "{time}"
        right:
          widgets:
            - id: built-in-memory
              type: memory
              format: " {usage}%"
      """

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    try manager.applyV1Configuration(yaml: yaml)

    XCTAssertEqual(manager.currentConfig.externalDisplay.left.first?.typeID, "music")
    XCTAssertEqual(manager.currentConfig.externalDisplay.center.first?.typeID, "music")
    XCTAssertEqual(manager.currentConfig.externalDisplay.right.first?.typeID, "cpu")
    XCTAssertEqual(manager.currentConfig.builtInDisplay.left.first?.typeID, "audio")
    XCTAssertEqual(manager.currentConfig.builtInDisplay.center.first?.typeID, "clock")
    XCTAssertEqual(manager.currentConfig.builtInDisplay.right.first?.typeID, "memory")
    XCTAssertEqual(manager.configurationForDisplay(isBuiltIn: false)?.global.style.color, "#111111")
    XCTAssertEqual(manager.configurationForDisplay(isBuiltIn: true)?.global.style.color, "#222222")
    XCTAssertEqual(manager.configurationForDisplay(isBuiltIn: false)?.global.barPadding.top, 1)
    XCTAssertEqual(manager.configurationForDisplay(isBuiltIn: true)?.global.barPadding.top, 2)

    manager.activateConfiguration(isBuiltIn: true)
    XCTAssertEqual(manager.currentV1Config?.center.centerDefault, "built-in-center")
    XCTAssertEqual(manager.currentConfig.colors.textPrimary, "#222222")
  }

  func testConfigManagerReadsExternalProfileFromLegacyCombinedRegularFile() throws {
    let legacyRegularYAML = """
      global:
        style:
          color: "#111111"
      external_monitor:
        center:
          center_default: regular-clock
          widgets:
            - id: regular-clock
              type: clock
              compact_format: "regular {time}"
      built_in_monitor:
        style:
          corner_radius: 0
        center:
          center_default: stale-built-in-clock
          widgets:
            - id: stale-built-in-clock
              type: clock
              compact_format: "stale {time}"
      """
    let builtInYAML = """
      global:
        style:
          color: "#222222"
      center:
        center_default: built-in-clock
        widgets:
          - id: built-in-clock
            type: clock
            compact_format: "built-in {time}"
      """

    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    try manager.applyV1Configurations(
      regularYAML: legacyRegularYAML,
      builtInYAML: builtInYAML
    )

    XCTAssertEqual(
      manager.configurationForDisplay(isBuiltIn: false)?.center.centerDefault,
      "regular-clock"
    )
    XCTAssertEqual(
      manager.configurationForDisplay(isBuiltIn: true)?.center.centerDefault,
      "built-in-clock"
    )
  }

  func testMusicFormatParserPreservesTextAndFindsComponents() {
    XCTAssertEqual(
      MusicFormatParser.parts(in: "{artwork} {title} {slider}"),
      [
        .artwork,
        .text(" {title} "),
        .slider,
      ]
    )
  }

  func testFormatRendererReplacesValuesAndSeparatesNerdFontRuns() {
    let rendered = KamidanaFormatRenderer.render(
      "󰍛 {usage}%",
      values: ["usage": "42.5"]
    )

    XCTAssertEqual(rendered, "󰍛 42.5%")
    XCTAssertEqual(
      KamidanaFormatRenderer.segments(in: rendered),
      [
        KamidanaFormatSegment(value: "󰍛", isIcon: true),
        KamidanaFormatSegment(value: " 42.5%", isIcon: false),
      ]
    )
  }

  func testNetworkDefaultFormatIncludesTheConnectionIcon() {
    let config = NetworkWidgetConfig()
    let rendered = KamidanaFormatRenderer.render(
      NetworkWidget.defaultFormat,
      values: [
        "connection_icon": config.wiredIcon,
        "ssid": "",
        "network_name": "Ethernet (en0)",
        "upload": "1 KB",
        "upload_icon": config.uploadIcon,
        "download": "2 KB",
        "download_icon": config.downloadIcon,
      ]
    )

    XCTAssertEqual(
      rendered,
      "\(config.wiredIcon) Ethernet (en0) 1 KB \(config.uploadIcon) 2 KB \(config.downloadIcon)"
    )
    XCTAssertEqual(KamidanaFormatRenderer.segments(in: rendered).first?.value, config.wiredIcon)
    XCTAssertTrue(KamidanaFormatRenderer.segments(in: rendered).first?.isIcon ?? false)
  }

  func testConfigManagerAppliesV1ConfigurationAtomically() throws {
    let manager = ConfigManager(shouldLoadUserConfiguration: false)
    let yaml = """
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    try manager.applyV1Configuration(yaml: yaml)
    XCTAssertEqual(manager.currentV1Config?.center.centerDefault, "clock")
    XCTAssertEqual(manager.currentConfig.externalDisplay.center.first?.typeID, "clock")

    XCTAssertThrowsError(try manager.applyV1Configuration(yaml: "center: invalid"))
    XCTAssertEqual(manager.currentV1Config?.center.centerDefault, "clock")
    XCTAssertEqual(manager.currentConfig.externalDisplay.center.first?.typeID, "clock")
  }

  func testExampleConfigurationUsesV1Schema() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let exampleURL = repositoryRoot.appendingPathComponent("Example/config.yaml")
    let yaml = try String(contentsOf: exampleURL, encoding: .utf8)
    let profiles = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: yaml)
    XCTAssertEqual(profiles.external.center.centerDefault, "music")
    XCTAssertEqual(profiles.builtIn.center.centerDefault, "music")
    XCTAssertTrue(profiles.external.global.hideInFullscreen)
    XCTAssertTrue(profiles.builtIn.global.hideInFullscreen)
    let cpu = try XCTUnwrap(profiles.external.right.widgets.first { $0.kind == .cpu })
    XCTAssertEqual(cpu.style?.color, "#a6e3a1")
    XCTAssertEqual(cpu.style?.iconColor, "#a6e3a1")
    XCTAssertEqual(profiles.builtIn.right.widgets.map(\.kind), [.cpu, .memory, .widgetFolder])
  }
}
