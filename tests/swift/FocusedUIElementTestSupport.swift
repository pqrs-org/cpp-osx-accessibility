// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import ApplicationServices

@MainActor
func makeFocusedUIElement(
  roleValue: CFTypeRef? = nil,
  roleError: AXError = .success,
  windowTitle: String? = nil,
  windowGeometry: WindowGeometry? = nil
) -> FocusedUIElement {
  let element = AXUIElementCreateApplication(100)
  let window = AXUIElementCreateApplication(101)
  let copyValue: AXAttributeReader = { target, attribute in
    if CFEqual(target, element), attribute == kAXRoleAttribute as CFString {
      return (roleError, roleValue)
    }
    if CFEqual(target, element), attribute == kAXWindowAttribute as CFString {
      return (.success, window)
    }
    if CFEqual(target, window), attribute == kAXTitleAttribute as CFString {
      return (.success, windowTitle.map { $0 as CFString })
    }
    return (.noValue, nil)
  }
  let context = FocusedUIElementAXContext(
    element: element, applicationElement: nil, copyValue: copyValue)

  return FocusedUIElement(
    context,
    processIdentifier: 100,
    copyValue: copyValue,
    readFallbackWindowGeometry: { _ in windowGeometry }
  )
}
