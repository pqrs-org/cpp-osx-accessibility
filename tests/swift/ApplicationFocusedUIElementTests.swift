// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import ApplicationServices
import XCTest

final class ApplicationFocusedUIElementTests: XCTestCase {
  func testApplicationRoleActivatesFocusBeforeFirstQuery() {
    let application = AXUIElementCreateApplication(100)
    let focusedElement = AXUIElementCreateApplication(101)
    var attributes: [String] = []
    var activated = false

    let result = copyApplicationFocusedUIElement(application) { element, attribute in
      XCTAssertTrue(CFEqual(element, application))
      attributes.append(attribute as String)
      if attribute == kAXRoleAttribute as CFString {
        activated = true
        return (.success, kAXApplicationRole as CFString)
      }
      return activated ? (.success, focusedElement) : (.noValue, nil)
    }

    XCTAssertEqual(attributes, [kAXRoleAttribute, kAXFocusedUIElementAttribute])
    XCTAssertTrue(result.map { CFEqual($0, focusedElement) } ?? false)
  }

  func testUnavailableApplicationRoleDoesNotPreventFocusQuery() {
    let application = AXUIElementCreateApplication(100)
    let focusedElement = AXUIElementCreateApplication(101)

    let result = copyApplicationFocusedUIElement(application) { _, attribute in
      if attribute == kAXRoleAttribute as CFString {
        return (.attributeUnsupported, nil)
      }
      return (.success, focusedElement)
    }

    XCTAssertTrue(result.map { CFEqual($0, focusedElement) } ?? false)
  }

  // Initialisation completes between polling ticks without an AX notification,
  // application switch, geometry change, or additional user input.
  @MainActor
  func testDelayedInitialisationRecoversThroughPolling() {
    let application = AXUIElementCreateApplication(100)
    let focusedElement = AXUIElementCreateApplication(101)
    var retryState = PQRSOSXAccessibility.FocusedUIElementRetryState()
    var activated = false
    var elementReady = false
    var focusedRole: String?
    var focusQueryCount = 0
    let copyValue: AXAttributeReader = { element, attribute in
      if CFEqual(element, application), attribute == kAXRoleAttribute as CFString {
        activated = true
        return (.success, kAXApplicationRole as CFString)
      }
      if CFEqual(element, application), attribute == kAXFocusedUIElementAttribute as CFString {
        focusQueryCount += 1
        return activated && elementReady ? (.success, focusedElement) : (.noValue, nil)
      }
      if CFEqual(element, focusedElement), attribute == kAXRoleAttribute as CFString {
        return (.success, focusedRole.map { $0 as CFString })
      }
      return (.noValue, nil)
    }

    func readFocusedElement() -> FocusedUIElement? {
      guard let element = copyApplicationFocusedUIElement(application, copyValue: copyValue) else {
        return nil
      }
      let context = FocusedUIElementAXContext(
        element: element, applicationElement: nil, copyValue: copyValue)
      return FocusedUIElement(context, processIdentifier: nil, copyValue: copyValue)
    }

    XCTAssertNil(readFocusedElement())
    XCTAssertTrue(activated)
    retryState.update(processIdentifier: 100, focusedRole: nil)

    elementReady = true
    XCTAssertTrue(retryState.takeRetry())
    let unreadableRoleElement = readFocusedElement()
    XCTAssertTrue(unreadableRoleElement != nil)
    XCTAssertNil(unreadableRoleElement?.role)
    retryState.update(processIdentifier: 100, focusedRole: unreadableRoleElement?.role)

    focusedRole = ""
    XCTAssertTrue(retryState.takeRetry())
    let emptyRoleElement = readFocusedElement()
    XCTAssertTrue(emptyRoleElement != nil)
    XCTAssertNil(emptyRoleElement?.role)
    retryState.update(processIdentifier: 100, focusedRole: emptyRoleElement?.role)

    focusedRole = "AXTextArea"
    XCTAssertTrue(retryState.takeRetry())
    let readyElement = readFocusedElement()
    retryState.update(processIdentifier: 100, focusedRole: readyElement?.role)

    XCTAssertEqual(readyElement?.role, "AXTextArea")
    XCTAssertEqual(focusQueryCount, 4)
    XCTAssertFalse(retryState.takeRetry())
  }

  func testFocusErrorDoesNotReturnAnElement() {
    let application = AXUIElementCreateApplication(100)

    let result = copyApplicationFocusedUIElement(application) { _, attribute in
      if attribute == kAXRoleAttribute as CFString {
        return (.success, kAXApplicationRole as CFString)
      }
      return (.cannotComplete, application)
    }

    XCTAssertNil(result)
  }

  func testMissingFocusValueDoesNotReturnAnElement() {
    let application = AXUIElementCreateApplication(100)

    let result = copyApplicationFocusedUIElement(application) { _, attribute in
      if attribute == kAXRoleAttribute as CFString {
        return (.success, kAXApplicationRole as CFString)
      }
      return (.success, nil)
    }

    XCTAssertNil(result)
  }

  func testUnexpectedFocusValueTypeDoesNotReturnAnElement() {
    let application = AXUIElementCreateApplication(100)

    let result = copyApplicationFocusedUIElement(application) { _, _ in
      (.success, kAXApplicationRole as CFString)
    }

    XCTAssertNil(result)
  }
}
