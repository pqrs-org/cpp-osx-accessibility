// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import AppKit
import ApplicationServices
import XCTest

@MainActor
final class MonitoringOptionsTests: XCTestCase {
  // The C API struct must preserve each independently selected capability.
  func testCMonitoringStructConvertsToOptions() {
    let monitoring = pqrs_osx_accessibility_monitoring(
      frontmost_application: true,
      focused_ui_element: false,
      focused_window: true
    )

    XCTAssertEqual(
      AccessibilityMonitoringOptions(monitoring),
      [.frontmostApplication, .focusedWindow]
    )
  }

  // Frontmost-application polling does not require per-application notifications.
  func testFrontmostApplicationOnlyDoesNotRegisterAccessibilityNotifications() {
    XCTAssertTrue(
      observedAccessibilityNotifications(monitoringOptions: [.frontmostApplication]).isEmpty)
  }

  // Focused-element monitoring subscribes only to focused-element changes.
  func testFocusedUIElementRegistersOnlyFocusedUIElementNotification() {
    XCTAssertEqual(
      observedAccessibilityNotifications(monitoringOptions: [.focusedUIElement]).map {
        $0 as String
      },
      [kAXFocusedUIElementChangedNotification]
    )
  }

  // Window monitoring subscribes only to notifications that can change window state.
  func testFocusedWindowRegistersOnlyWindowNotifications() {
    XCTAssertEqual(
      observedAccessibilityNotifications(monitoringOptions: [.focusedWindow]).map { $0 as String },
      [
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
      ]
    )
  }

  // With every capability disabled, snapshot creation must remain on the NSWorkspace path.
  func testAllFeaturesDisabledPerformsNoAccessibilityAcquisition() {
    let fixture = SnapshotAcquisitionFixture()

    _ = fixture.readSnapshot(monitoringOptions: [])

    XCTAssertEqual(fixture.systemWideElementCreateCount, 0)
    XCTAssertEqual(fixture.applicationElementCreateCount, 0)
    XCTAssertTrue(fixture.copiedAttributes.isEmpty)
    XCTAssertEqual(fixture.fallbackWindowGeometryReadCount, 0)
  }

  // Frontmost detection uses system-wide AX without creating a per-application AX element.
  func testFrontmostApplicationUsesOnlySystemWideAccessibilityAcquisition() {
    let fixture = SnapshotAcquisitionFixture()

    _ = fixture.readSnapshot(monitoringOptions: [.frontmostApplication])

    XCTAssertEqual(fixture.systemWideElementCreateCount, 1)
    XCTAssertEqual(fixture.applicationElementCreateCount, 0)
    XCTAssertEqual(
      fixture.copiedAttributes,
      [
        kAXFocusedApplicationAttribute as String,
        kAXFocusedUIElementAttribute as String,
      ]
    )
    XCTAssertEqual(fixture.fallbackWindowGeometryReadCount, 0)
  }

  // The application role read initializes AX in apps such as Chrome before reading focus.
  func testFocusedUIElementUsesOnlyApplicationFocusedElementAcquisition() {
    let fixture = SnapshotAcquisitionFixture()

    _ = fixture.readSnapshot(monitoringOptions: [.focusedUIElement])

    XCTAssertEqual(fixture.systemWideElementCreateCount, 0)
    XCTAssertEqual(fixture.applicationElementCreateCount, 1)
    XCTAssertEqual(
      fixture.copiedAttributes,
      [
        kAXRoleAttribute as String,
        kAXFocusedUIElementAttribute as String,
      ]
    )
    XCTAssertEqual(fixture.fallbackWindowGeometryReadCount, 0)
  }

  // Window-only monitoring reads the focused window and may fall back to Core Graphics geometry.
  func testFocusedWindowUsesOnlyApplicationWindowAcquisition() {
    let fixture = SnapshotAcquisitionFixture()

    _ = fixture.readSnapshot(monitoringOptions: [.focusedWindow])

    XCTAssertEqual(fixture.systemWideElementCreateCount, 0)
    XCTAssertEqual(fixture.applicationElementCreateCount, 1)
    XCTAssertEqual(fixture.copiedAttributes, [kAXFocusedWindowAttribute as String])
    XCTAssertEqual(fixture.fallbackWindowGeometryReadCount, 1)
  }

  // System-wide frontmost detection alone must not attach an AXObserver to the application.
  func testFrontmostApplicationOnlyDoesNotCreateApplicationObserver() {
    var observerCreateCount = 0
    let controller = PQRSOSXAccessibility.ObservationController(
      monitoringOptions: [.frontmostApplication],
      createObserver: { _, _, _ in
        observerCreateCount += 1
        return .failure
      }
    )

    controller.syncObservers(
      frontmostProcessIdentifier: NSRunningApplication.current.processIdentifier,
      titleNotificationElements: []
    )

    XCTAssertEqual(observerCreateCount, 0)
  }

  // Either focused capability needs a per-application observer for its notifications.
  func testEachFocusedFeatureCreatesApplicationObserver() {
    for options: AccessibilityMonitoringOptions in [.focusedUIElement, .focusedWindow] {
      var observerCreateCount = 0
      let controller = PQRSOSXAccessibility.ObservationController(
        monitoringOptions: options,
        createObserver: { _, _, _ in
          observerCreateCount += 1
          return .failure
        }
      )

      controller.syncObservers(
        frontmostProcessIdentifier: NSRunningApplication.current.processIdentifier,
        titleNotificationElements: []
      )

      XCTAssertEqual(observerCreateCount, 1)
    }
  }
}

@MainActor
private final class SnapshotAcquisitionFixture {
  private(set) var systemWideElementCreateCount = 0
  private(set) var applicationElementCreateCount = 0
  private(set) var copiedAttributes: [String] = []
  private(set) var fallbackWindowGeometryReadCount = 0

  func readSnapshot(
    monitoringOptions: AccessibilityMonitoringOptions
  ) -> SnapshotCopyResult {
    let runningApplication = NSRunningApplication.current
    let cachedApplication = FrontmostApplication(
      runningApplication,
      detectionSource: .workspace
    )
    let dependencies = SnapshotCopyDependencies(
      readWorkspaceFrontmostApplication: { runningApplication },
      createSystemWideElement: {
        self.systemWideElementCreateCount += 1
        return AXUIElementCreateSystemWide()
      },
      createApplicationElement: { processIdentifier in
        self.applicationElementCreateCount += 1
        return AXUIElementCreateApplication(processIdentifier)
      },
      copyValue: { _, attribute in
        self.copiedAttributes.append(attribute as String)
        return (.noValue, nil)
      },
      readFallbackWindowGeometry: { _ in
        self.fallbackWindowGeometryReadCount += 1
        return nil
      }
    )

    return copySnapshot(
      cachedApplication: cachedApplication,
      monitoringOptions: monitoringOptions,
      resolveProcessIdentifiers: { processIdentifiers in
        PQRSOSXAccessibility.FrontmostProcessIdentifierResolution(
          processIdentifier: processIdentifiers.workspacePid,
          detectionSource: processIdentifiers.workspacePid == nil ? .none : .workspace,
          sourceProcessIdentifiers: processIdentifiers
        )
      },
      handleProcessIdentifier: { _, _ in },
      dependencies: dependencies
    )
  }
}
