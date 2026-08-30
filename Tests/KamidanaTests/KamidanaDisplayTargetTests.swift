import XCTest

@testable import KamidanaApp

final class KamidanaDisplayTargetTests: XCTestCase {
  private let screens = [
    KamidanaDisplayTargetScreen(
      id: 11, name: "Built-in Retina Display", isBuiltIn: true, isPrimary: true
    ),
    KamidanaDisplayTargetScreen(
      id: 44, name: "Sidecar Display", isBuiltIn: false, isPrimary: false
    ),
    KamidanaDisplayTargetScreen(
      id: 22, name: "Studio Display", isBuiltIn: false, isPrimary: false
    ),
  ]

  func testDecodesAllDisplayTargetKinds() throws {
    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: """
      global:
        display_targets:
          - kind: primary
          - kind: secondary
          - kind: built_in
          - kind: external
          - kind: all
          - kind: name
            name: "Studio Display"
          - kind: id
            id: 22
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """)

    XCTAssertEqual(
      configuration.global.displayTargets,
      [
        KamidanaDisplayTarget(kind: .primary),
        KamidanaDisplayTarget(kind: .secondary),
        KamidanaDisplayTarget(kind: .builtIn),
        KamidanaDisplayTarget(kind: .external),
        KamidanaDisplayTarget(kind: .all),
        KamidanaDisplayTarget(kind: .name, name: "Studio Display"),
        KamidanaDisplayTarget(kind: .id, id: 22),
      ]
    )
  }

  func testDefaultsDisplayTargetsToPrimary() throws {
    let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: """
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """)

    XCTAssertEqual(configuration.global.displayTargets, [KamidanaDisplayTarget(kind: .primary)])
  }

  func testRejectsEmptyDisplayTargets() {
    let yaml = """
      global:
        display_targets: []
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """

    XCTAssertThrowsError(try KamidanaConfigurationV1Decoder.decode(yaml: yaml)) { error in
      guard case KamidanaConfigurationV1Error.invalidDisplayTarget = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testRejectsMalformedDisplayTargets() {
    assertDisplayTargetError("""
      - kind: name
      """)
    assertDisplayTargetError("""
      - kind: name
        name: "   "
      """)
    assertDisplayTargetError("""
      - kind: id
        id: 0
      """)
    assertDisplayTargetError("""
      - kind: primary
        name: "Studio Display"
      """)
    assertDisplayTargetError("""
      - kind: name
        name: "Studio Display"
        id: 22
      """)
  }

  func testRejectsUnknownDisplayTargetKindAndStructure() {
    let unknownKind = configurationYAML(displayTargets: """
      - kind: projector
      """)
    let unknownField = configurationYAML(displayTargets: """
      - kind: name
        display_name: "Studio Display"
      """)

    for yaml in [unknownKind, unknownField] {
      XCTAssertThrowsError(try KamidanaConfigurationV1Decoder.decode(yaml: yaml)) { error in
        guard case KamidanaConfigurationV1Error.yamlDecoding = error else {
          return XCTFail("Unexpected error: \(error)")
        }
      }
    }
  }

  func testResolvesOverlappingSecondaryNameAndIDTargetsInScreenOrder() {
    let resolved = KamidanaDisplayTargetResolver.resolve(
      targets: [
        KamidanaDisplayTarget(kind: .name, name: "Studio Display"),
        KamidanaDisplayTarget(kind: .id, id: 44),
        KamidanaDisplayTarget(kind: .secondary),
        KamidanaDisplayTarget(kind: .primary),
      ],
      screens: screens
    )

    XCTAssertEqual(resolved.map(\.id), [11, 44, 22])
  }

  func testResolvesBuiltInExternalAllAndExactSelectors() {
    XCTAssertEqual(
      KamidanaDisplayTargetResolver.resolve(
        targets: [KamidanaDisplayTarget(kind: .builtIn)], screens: screens
      ).map(\.id),
      [11]
    )
    XCTAssertEqual(
      KamidanaDisplayTargetResolver.resolve(
        targets: [KamidanaDisplayTarget(kind: .external)], screens: screens
      ).map(\.id),
      [44, 22]
    )
    XCTAssertEqual(
      KamidanaDisplayTargetResolver.resolve(
        targets: [KamidanaDisplayTarget(kind: .all)], screens: screens
      ).map(\.id),
      [11, 44, 22]
    )
    XCTAssertEqual(
      KamidanaDisplayTargetResolver.resolve(
        targets: [KamidanaDisplayTarget(kind: .name, name: "Studio Display")], screens: screens
      ).map(\.id),
      [22]
    )
    XCTAssertEqual(
      KamidanaDisplayTargetResolver.resolve(
        targets: [KamidanaDisplayTarget(kind: .id, id: 44)], screens: screens
      ).map(\.id),
      [44]
    )
  }

  private func assertDisplayTargetError(
    _ displayTargets: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(
      try KamidanaConfigurationV1Decoder.decode(
        yaml: configurationYAML(displayTargets: displayTargets)
      ),
      file: file,
      line: line
    ) { error in
      guard case KamidanaConfigurationV1Error.invalidDisplayTarget = error else {
        return XCTFail("Unexpected error: \(error)", file: file, line: line)
      }
    }
  }

  private func configurationYAML(displayTargets: String) -> String {
    let indentedDisplayTargets = displayTargets
      .split(separator: "\n")
      .map { "    \($0)" }
      .joined(separator: "\n")
    return """
      global:
        display_targets:
      \(indentedDisplayTargets)
      center:
        center_default: clock
        widgets:
          - id: clock
            type: clock
            compact_format: "{time}"
      """
  }
}
