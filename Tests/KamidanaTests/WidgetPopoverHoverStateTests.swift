import XCTest

@testable import Kamidana

final class WidgetPopoverHoverStateTests: XCTestCase {
  func testPopoverStaysPresentedWhileEitherSurfaceIsHovered() {
    XCTAssertTrue(WidgetPopoverHoverState.shouldRemainPresented(anchorHovered: true, popoverHovered: false))
    XCTAssertTrue(WidgetPopoverHoverState.shouldRemainPresented(anchorHovered: false, popoverHovered: true))
    XCTAssertFalse(WidgetPopoverHoverState.shouldRemainPresented(anchorHovered: false, popoverHovered: false))
  }
}
