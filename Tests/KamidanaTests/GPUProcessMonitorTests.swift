import XCTest

@testable import KamidanaApp

final class GPUProcessMonitorTests: XCTestCase {
  func testParsesGPUClientCreator() {
    XCTAssertEqual(GPUProcessMonitor.processIdentifier(from: "pid 42, Example"), 42)
    XCTAssertNil(GPUProcessMonitor.processIdentifier(from: "invalid creator"))
    XCTAssertEqual(GPUProcessMonitor.processName(from: "pid 42, Example"), "Example")
  }

  func testSumsAccumulatedGPUTimeAcrossCommandQueues() {
    let total = GPUProcessMonitor.accumulatedGPUTime(from: [
      ["accumulatedGPUTime": NSNumber(value: 120)],
      ["accumulatedGPUTime": NSNumber(value: 80)],
      ["API": "Metal"],
    ])
    XCTAssertEqual(total, 200)
  }
}
