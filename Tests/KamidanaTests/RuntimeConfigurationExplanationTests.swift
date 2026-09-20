import XCTest

@testable import KamidanaApp

final class RuntimeConfigurationExplanationTests: XCTestCase {
  func testRuntimeExplanationPreservesWidgetHierarchyAndEffectiveActivation() throws {
    let child = KamidanaRuntimeWidget(
      id: "sleep",
      type: "system-action-child",
      path: "left.widgets[0].children[0]",
      activation: .click,
      activationSource: "widget",
      animation: .dynamic,
      style: KamidanaStyle(color: "#ffffff"),
      popupStyle: KamidanaStyle(),
      action: "sleep",
      format: "Sleep",
      icon: "icon-sleep"
    )
    let parent = KamidanaRuntimeWidget(
      id: "system-actions",
      type: "widget-folder",
      path: "left.widgets[0]",
      activation: .click,
      activationSource: "widget",
      animation: .dynamic,
      style: KamidanaStyle(background: "#111111"),
      popupStyle: KamidanaStyle(),
      children: [child]
    )
    let explanation = KamidanaRuntimeConfiguration(
      pid: 123,
      process: "Kamidana",
      generatedAt: "2026-09-20T00:00:00Z",
      requestID: "request-1",
      configPath: "/tmp/config.yaml",
      source: "monitor_profiles",
      displays: [
        "JAPANNEXT MNT": KamidanaRuntimeDisplay(
          centerDefault: "music",
          left: KamidanaRuntimeSection(activation: nil, widgets: [parent]),
          center: KamidanaRuntimeSection(activation: nil, widgets: []),
          right: KamidanaRuntimeSection(activation: nil, widgets: [])
        )
      ],
      activeScreens: [
        KamidanaRuntimeScreen(
          name: "JAPANNEXT MNT",
          displayID: 42,
          isBuiltIn: false,
          profile: "JAPANNEXT MNT"
        )
      ]
    )

    let data = try JSONEncoder().encode(explanation)
    let decoded = try JSONDecoder().decode(
      KamidanaRuntimeConfiguration.self,
      from: data
    )
    let decodedParent = try XCTUnwrap(decoded.displays["JAPANNEXT MNT"]?.left.widgets.first)
    let decodedChild = try XCTUnwrap(decodedParent.children.first)

    XCTAssertEqual(decodedParent.id, "system-actions")
    XCTAssertEqual(decoded.requestID, "request-1")
    XCTAssertEqual(decodedParent.activation, .click)
    XCTAssertEqual(decodedChild.id, "sleep")
    XCTAssertEqual(decodedChild.activation, .click)
    XCTAssertEqual(decodedChild.action, "sleep")
    XCTAssertEqual(decoded.activeScreens.first?.profile, "JAPANNEXT MNT")
  }
}
