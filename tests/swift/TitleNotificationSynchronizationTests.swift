// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import ApplicationServices
import XCTest

final class TitleNotificationSynchronizationTests: XCTestCase {
  private let previousElement = AXUIElementCreateApplication(100)
  private let currentElement = AXUIElementCreateApplication(200)

  // A terminal registration failure is not retried while the desired elements
  // remain unchanged; lightweight title polling covers this case.
  func testMissingRegistrationDoesNotRequireSynchronization() {
    XCTAssertFalse(
      titleNotificationsNeedSynchronization(
        requestedElements: [currentElement],
        registeredElements: [],
        desiredElements: [currentElement]
      )
    )
  }

  // A stale registration retained after a removal failure requires another
  // synchronization attempt even when the desired elements are unchanged.
  func testStaleRegistrationRequiresSynchronization() {
    XCTAssertTrue(
      titleNotificationsNeedSynchronization(
        requestedElements: [currentElement],
        registeredElements: [previousElement, currentElement],
        desiredElements: [currentElement]
      )
    )
  }

  // A change in the desired elements always requires synchronization.
  func testChangedDesiredElementsRequireSynchronization() {
    XCTAssertTrue(
      titleNotificationsNeedSynchronization(
        requestedElements: [previousElement],
        registeredElements: [previousElement],
        desiredElements: [currentElement]
      )
    )
  }

  // A transient registration error is classified for a later retry.
  func testTransientRegistrationErrorRequiresRetry() {
    XCTAssertEqual(
      accessibilityNotificationAddDisposition(.cannotComplete),
      .retry
    )
  }

  // An unsupported notification is not retried for the same AX element.
  func testUnsupportedRegistrationStopsTrying() {
    XCTAssertEqual(
      accessibilityNotificationAddDisposition(.notificationUnsupported),
      .stopTrying
    )
  }

  // Removing a notification that is no longer registered stops tracking it.
  func testMissingRegistrationRemovalStopsTracking() {
    XCTAssertEqual(
      accessibilityNotificationRemoveDisposition(.notificationNotRegistered),
      .stopTracking
    )
  }

  // An invalid AX element can no longer deliver notifications, so its
  // registration is no longer tracked.
  func testInvalidElementRemovalStopsTracking() {
    XCTAssertEqual(
      accessibilityNotificationRemoveDisposition(.invalidUIElement),
      .stopTracking
    )
  }

  // An invalid observer requires the whole observer registration to be rebuilt.
  func testInvalidObserverRequiresRecreation() {
    XCTAssertEqual(
      accessibilityNotificationRemoveDisposition(.invalidUIElementObserver),
      .invalidateObserver
    )
  }
}
