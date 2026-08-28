// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import XCTest

final class AccessibilityNotificationRefreshScheduleStateTests: XCTestCase {
  // The first notification schedules the delayed refresh task.
  func testFirstNotificationSchedulesRefresh() {
    var state = PQRSOSXAccessibility.AccessibilityNotificationRefreshScheduleState()

    XCTAssertTrue(state.schedule())
  }

  // Additional notifications are coalesced while a refresh task is scheduled.
  func testAdditionalNotificationsDoNotScheduleRefresh() {
    var state = PQRSOSXAccessibility.AccessibilityNotificationRefreshScheduleState()

    XCTAssertTrue(state.schedule())
    XCTAssertFalse(state.schedule())
  }

  // Resetting after completion or cancellation allows the next notification to
  // schedule a refresh.
  func testResetAllowsNextRefresh() {
    var state = PQRSOSXAccessibility.AccessibilityNotificationRefreshScheduleState()

    XCTAssertTrue(state.schedule())
    state.reset()
    XCTAssertTrue(state.schedule())
  }
}
