import XCTest
import SwiftUI

@testable import KamidanaApp

final class WidgetPopoverHoverStateTests: XCTestCase {
  func testThemeMotionProvidesDedicatedInteractionTokens() {
    let motion = Theme.Motion.standard

    XCTAssertEqual(motion.hover.durationSeconds, 0.15)
    XCTAssertEqual(motion.expand.response, 0.3)
    XCTAssertEqual(motion.expand.damping, 0.85)
    XCTAssertEqual(motion.colorChange.durationSeconds, 0.2)
    XCTAssertEqual(motion.animation(for: .hover), motion.hover)
    XCTAssertEqual(motion.animation(for: .pressed), motion.colorChange)
  }

  func testHoverAndPressedAppearanceDoNotChangeBaseLayoutTokens() {
    let theme = Theme(
      padding: KamidanaInsets(top: 6, bottom: 8, leading: 10, trailing: 10),
      cornerRadius: 12,
      hoverTheme: Theme.HoverTheme(scale: 1.08),
      pressedTheme: Theme.PressedTheme(opacity: 0.88)
    )

    XCTAssertEqual(theme.padding.leading, 10)
    XCTAssertEqual(theme.padding.trailing, 10)
    XCTAssertEqual(theme.cornerRadius, 12)
    XCTAssertEqual(theme.hoverTheme?.scale, 1.08)
    XCTAssertEqual(theme.pressedTheme?.opacity, 0.88)
  }

  func testHoverTrackerDropsAStaleEnterWhenPointerLeavesImmediately() {
    let tracker = WidgetHoverTracker()
    var appliedValues: [Bool] = []

    tracker.update(true, delay: 0.01) { appliedValues.append($0) }
    tracker.update(false, delay: 0.01) { appliedValues.append($0) }

    let expectation = expectation(description: "hover transition settles")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 0.2)

    XCTAssertTrue(appliedValues.isEmpty)
  }

  func testHoverTrackerAppliesAStableEnter() {
    let tracker = WidgetHoverTracker()
    let expectation = expectation(description: "hover enters")
    var appliedValue: Bool?

    tracker.update(true, delay: 0.01) {
      appliedValue = $0
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 0.2)

    XCTAssertEqual(appliedValue, true)
  }

  func testClickActivationCanRepeatAcrossOpenAndCloseCycles() {
    let controller = WidgetInteractionController()

    for _ in 0..<4 {
      XCTAssertTrue(controller.activate(.click))
      XCTAssertTrue(controller.isPresented)
      XCTAssertFalse(controller.activate(.hover))
      XCTAssertTrue(controller.isPresented)

      XCTAssertFalse(controller.activate(.click))
      XCTAssertFalse(controller.isPresented)
    }
  }

  func testHoverActivationCanRepeatAcrossOpenAndCloseCycles() {
    let controller = WidgetInteractionController()

    for _ in 0..<3 {
      controller.updateAnchorHover(
        true,
        activation: .hover,
        settleDelay: 0.01,
        dismissDelay: 0.02
      )
      waitForMainQueue(0.03)
      XCTAssertTrue(controller.isPresented)

      controller.updateAnchorHover(
        false,
        activation: .hover,
        settleDelay: 0.01,
        dismissDelay: 0.02
      )
      controller.updatePopupHover(
        false,
        activation: .hover,
        settleDelay: 0.01,
        dismissDelay: 0.02
      )
      waitForMainQueue(0.05)
      XCTAssertFalse(controller.isPresented)
    }
  }

  func testHoverReentryCancelsPendingDismissal() {
    let controller = WidgetInteractionController()

    controller.updateAnchorHover(
      true,
      activation: .hover,
      settleDelay: 0.01,
      dismissDelay: 0.05
    )
    waitForMainQueue(0.03)
    XCTAssertTrue(controller.isPresented)

    controller.updateAnchorHover(
      false,
      activation: .hover,
      settleDelay: 0.01,
      dismissDelay: 0.05
    )
    waitForMainQueue(0.02)
    controller.updateAnchorHover(
      true,
      activation: .hover,
      settleDelay: 0.01,
      dismissDelay: 0.05
    )
    waitForMainQueue(0.08)
    XCTAssertTrue(controller.isPresented)
  }

  private func waitForMainQueue(_ interval: TimeInterval) {
    let expectation = expectation(description: "main queue settles")
    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: interval + 0.2)
  }
}
