// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import XCTest

final class FocusedUIElementRetryStateTests: XCTestCase {
  func testNoRetryBeforeAnApplicationIsObserved() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()

    XCTAssertFalse(state.takeRetry())
    state.update(processIdentifier: nil, focusedRole: nil)
    XCTAssertFalse(state.takeRetry())
  }

  func testMissingFocusHasABoundedRetryBudget() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)

    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      XCTAssertTrue(state.takeRetry())
      // Rebuilding the same missing-focus snapshot must not replenish retries.
      state.update(processIdentifier: 100, focusedRole: nil)
    }

    XCTAssertFalse(state.takeRetry())
    state.update(processIdentifier: 100, focusedRole: nil)
    XCTAssertFalse(state.takeRetry())
  }

  func testAvailableFocusDoesNotScheduleRetries() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: "AXTextArea")

    XCTAssertFalse(state.takeRetry())
  }

  func testEmptyRoleDoesNotStopPendingRetries() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)

    state.update(processIdentifier: 100, focusedRole: "")

    XCTAssertTrue(state.takeRetry())
  }

  func testFocusRecoveryStopsPendingRetries() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)
    XCTAssertTrue(state.takeRetry())

    state.update(processIdentifier: 100, focusedRole: "AXTextArea")

    XCTAssertFalse(state.takeRetry())
  }

  func testSwitchingToAnApplicationWithFocusCancelsRetries() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)

    state.update(processIdentifier: 101, focusedRole: "AXTextArea")

    XCTAssertFalse(state.takeRetry())
  }

  func testSwitchingApplicationsStartsANewRecoveryAttempt() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)
    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      XCTAssertTrue(state.takeRetry())
    }
    XCTAssertFalse(state.takeRetry())

    state.update(processIdentifier: 101, focusedRole: nil)

    XCTAssertTrue(state.takeRetry())
  }

  func testLosingFocusAfterRecoveryStartsANewAttempt() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)
    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      XCTAssertTrue(state.takeRetry())
    }
    state.update(processIdentifier: 100, focusedRole: "AXTextArea")

    state.update(processIdentifier: 100, focusedRole: nil)

    XCTAssertTrue(state.takeRetry())
  }

  func testLosingTheApplicationClearsPendingRetries() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)

    state.update(processIdentifier: nil, focusedRole: nil)

    XCTAssertFalse(state.takeRetry())
    state.update(processIdentifier: 100, focusedRole: nil)
    XCTAssertTrue(state.takeRetry())
  }

  func testResetDiscardsPendingRetries() {
    var state = PQRSOSXAccessibility.FocusedUIElementRetryState()
    state.update(processIdentifier: 100, focusedRole: nil)

    state = PQRSOSXAccessibility.FocusedUIElementRetryState()

    XCTAssertFalse(state.takeRetry())
  }
}
