import XCTest

@testable import Kamidana

final class MemoryWidgetTests: XCTestCase {
  func testMemoryFormatValuesProvideUsedTotalAndPercentage() {
    let values = MemoryWidget.formatValues(
      usedMB: 8_192,
      totalBytes: 16 * 1_073_741_824
    )

    XCTAssertEqual(values["used_gb"], "8.0")
    XCTAssertEqual(values["total_gb"], "16.0")
    XCTAssertEqual(values["usage"], "50.0")
  }
}
