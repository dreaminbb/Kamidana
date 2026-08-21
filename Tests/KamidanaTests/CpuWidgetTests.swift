import XCTest

@testable import KamidanaApp

final class CpuWidgetTests: XCTestCase {
  func testCoreGraphRequiresUsablePerCoreData() {
    XCTAssertFalse(CpuWidget.canDisplayCoreGraph(for: nil))
    XCTAssertFalse(CpuWidget.canDisplayCoreGraph(for: CPUUsageInfo(total: 20, perCore: [])))
    XCTAssertFalse(CpuWidget.canDisplayCoreGraph(for: CPUUsageInfo(total: 20, perCore: [.nan])))
    XCTAssertTrue(CpuWidget.canDisplayCoreGraph(for: CPUUsageInfo(total: 20, perCore: [15, 42])))
  }

  func testCPUProcessListHasAFixedLimit() {
    XCTAssertEqual(CpuWidget.processListLimit, 8)
  }
}
