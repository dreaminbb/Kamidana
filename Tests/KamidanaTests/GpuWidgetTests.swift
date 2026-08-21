import XCTest

@testable import KamidanaApp

final class GpuWidgetTests: XCTestCase {
  func testGPUUsageFallsBackWhenDataIsUnavailable() {
    XCTAssertEqual(GpuWidget.displayUsage(nil), "--")
    XCTAssertEqual(GpuWidget.displayUsage(GPUUsageInfo(activeRatio: .nan)), "--")
    XCTAssertEqual(GpuWidget.displayUsage(GPUUsageInfo(activeRatio: 42.5)), "42.5")
  }
}
