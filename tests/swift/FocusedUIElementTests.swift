// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import ApplicationServices
import XCTest

@MainActor
final class FocusedUIElementTests: XCTestCase {
  func testMissingRoleRemainsUnavailable() {
    XCTAssertNil(makeFocusedUIElement().role)
  }

  func testEmptyRoleIsNormalisedToNil() {
    XCTAssertNil(makeFocusedUIElement(roleValue: "" as CFString).role)
  }

  func testUnreadableRoleRemainsUnavailable() {
    XCTAssertNil(
      makeFocusedUIElement(roleValue: "AXTextArea" as CFString, roleError: .cannotComplete).role)
  }

  func testInvalidRoleTypeRemainsUnavailable() {
    XCTAssertNil(makeFocusedUIElement(roleValue: 42 as CFNumber).role)
  }

  func testNonEmptyRolesArePreserved() {
    for role in ["AXTextArea", "AXButton", "AXUnknown"] {
      XCTAssertEqual(makeFocusedUIElement(roleValue: role as CFString).role, role)
    }
  }

  // A Core Graphics geometry update replaces only the window geometry and keeps
  // the geometry source marked as Core Graphics.
  func testUpdatingCoreGraphicsWindowGeometry() {
    let element = FocusedUIElement(
      windowGeometry: WindowGeometry(
        position: WindowPosition(x: 10, y: 20),
        size: WindowSize(width: 30, height: 40)
      )
    )

    let updated = element.updatingCoreGraphicsWindowGeometry(
      WindowGeometry(
        position: WindowPosition(x: 50, y: 60),
        size: WindowSize(width: 70, height: 80)
      )
    )

    XCTAssertEqual(updated.windowPosition, WindowPosition(x: 50, y: 60))
    XCTAssertEqual(updated.windowSize, WindowSize(width: 70, height: 80))
    XCTAssertEqual(updated.windowGeometrySource, .coreGraphics)
  }

  // Losing the Core Graphics geometry clears the position and size and resets
  // the geometry source.
  func testClearingCoreGraphicsWindowGeometry() {
    let element = FocusedUIElement(
      windowGeometry: WindowGeometry(
        position: WindowPosition(x: 10, y: 20),
        size: WindowSize(width: 30, height: 40)
      )
    )

    let updated = element.updatingCoreGraphicsWindowGeometry(nil)

    XCTAssertNil(updated.windowPosition)
    XCTAssertNil(updated.windowSize)
    XCTAssertEqual(updated.windowGeometrySource, .none)
  }
}
