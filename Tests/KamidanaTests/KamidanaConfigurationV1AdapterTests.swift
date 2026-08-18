import XCTest

@testable import Kamidana

final class KamidanaConfigurationV1AdapterTests: XCTestCase {
  func testAdapterPreservesSectionAndWidgetStyleAndCenterDefaultOrder() throws {
    let yaml = """
      global:
        style:
          background: "#101010"
          color: "#eeeeee"
      left:
        style:
          padding: 9
        widgets:
          - id: left-cpu
            type: cpu
            format: "󰍛 {usage}%"
            style:
              icon_color: "#ff0000"
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
        "upload": "1 KB",
        "upload_icon": config.uploadIcon,
        "download": "2 KB",
        "download_icon": config.downloadIcon,
      ]
    )

    XCTAssertEqual(rendered, "\(config.wiredIcon)  1 KB \(config.uploadIcon) 2 KB \(config.downloadIcon)")
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
    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    XCTAssertEqual(configuration.center.centerDefault, "music")
    XCTAssertTrue(configuration.global.hideInFullscreen)
    let cpu = try XCTUnwrap(configuration.right.widgets.first { $0.kind == .cpu })
    XCTAssertEqual(cpu.style?.color, "#a6e3a1")
    XCTAssertEqual(cpu.style?.iconColor, "#a6e3a1")
  }
}
