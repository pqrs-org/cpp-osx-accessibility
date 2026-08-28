// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import XCTest

final class FocusedUIElementTests: XCTestCase {
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
