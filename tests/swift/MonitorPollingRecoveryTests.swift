// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import AppKit
import XCTest

@MainActor
private final class MonitorPollingFixture {
  var application: FrontmostApplication?
  var processIdentifiers: PQRSOSXAccessibility.FrontmostProcessIdentifiers
  var element: FocusedUIElement?
  var lightweightGeometry: WindowGeometry?
  var snapshotReadCount = 0
  var processIdentifierReadCount = 0
  var lightweightGeometryReadCount = 0
  var snapshotMonitoringOptions: [AccessibilityMonitoringOptions] = []
  var observationControllerMonitoringOptions: [AccessibilityMonitoringOptions] = []

  init() {
    let application = FrontmostApplication(
      NSRunningApplication.current,
      detectionSource: .workspace
    )
    self.application = application
    processIdentifiers = PQRSOSXAccessibility.FrontmostProcessIdentifiers(
      axPid: application.processIdentifier,
      workspacePid: application.processIdentifier
    )
  }

  func makeMonitor() -> PQRSOSXAccessibility.Monitor {
    return PQRSOSXAccessibility.Monitor(
      readSnapshot: { _, monitoringOptions, resolveProcessIdentifiers, _ in
        self.snapshotReadCount += 1
        self.snapshotMonitoringOptions.append(monitoringOptions)
        _ = resolveProcessIdentifiers(self.processIdentifiers)
        return SnapshotCopyResult(
          snapshot: Snapshot(application: self.application, focusedUIElement: self.element),
          titleNotificationElements: []
        )
      },
      readProcessIdentifiers: { _ in
        self.processIdentifierReadCount += 1
        return self.processIdentifiers
      },
      readWindowGeometry: { _ in
        self.lightweightGeometryReadCount += 1
        return self.lightweightGeometry
      },
      makeObservationController: { monitoringOptions in
        self.observationControllerMonitoringOptions.append(monitoringOptions)
        return nil
      }
    )
  }
}

@MainActor
final class MonitorPollingRecoveryTests: XCTestCase {
  private struct PublishedSnapshot {
    let processIdentifier: pid_t?
    let role: String?
    let windowTitle: String?
    let x: Double?
    let width: Double?
  }

  private static var publishedSnapshots: [PublishedSnapshot] = []

  func testRecoverySnapshotPublishesGeometryAndTitleChangesWithoutARole() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement(windowTitle: "Before", windowGeometry: geometry(x: 10))
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor)

    fixture.element = makeFocusedUIElement(windowTitle: "After", windowGeometry: geometry(x: 20))
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 2)
    XCTAssertEqual(fixture.lightweightGeometryReadCount, 0)
    XCTAssertEqual(Self.publishedSnapshots.count, 2)
    XCTAssertNil(Self.publishedSnapshots.last?.role)
    XCTAssertEqual(Self.publishedSnapshots.last?.windowTitle, "After")
    XCTAssertEqual(Self.publishedSnapshots.last?.x, 20)
    XCTAssertEqual(Self.publishedSnapshots.last?.width, 40)
  }

  func testLightweightGeometryPollingResumesAfterRoleRecovery() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement(windowGeometry: geometry(x: 10))
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor)

    fixture.element = makeFocusedUIElement(
      roleValue: "AXTextArea" as CFString, windowTitle: "Ready", windowGeometry: geometry(x: 20))
    monitor.refreshIfPollingNeedsSnapshot()
    fixture.lightweightGeometry = geometry(x: 30)
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 2)
    XCTAssertEqual(fixture.lightweightGeometryReadCount, 1)
    XCTAssertEqual(Self.publishedSnapshots.last?.role, "AXTextArea")
    XCTAssertEqual(Self.publishedSnapshots.last?.windowTitle, "Ready")
    XCTAssertEqual(Self.publishedSnapshots.last?.x, 30)
  }

  func testLightweightGeometryPollingResumesAfterRetryExhaustion() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement(windowGeometry: geometry(x: 10))
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor)
    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      monitor.refreshIfPollingNeedsSnapshot()
    }

    fixture.lightweightGeometry = geometry(x: 30)
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 1 + focusedUIElementRoleRecoveryMaxPolls)
    XCTAssertEqual(fixture.lightweightGeometryReadCount, 1)
    XCTAssertEqual(Self.publishedSnapshots.last?.x, 30)
  }

  func testEmptyRoleIsPublishedAsUnavailableAndRecoveryContinues() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement(roleValue: "" as CFString)
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor)
    XCTAssertEqual(Self.publishedSnapshots.count, 1)
    XCTAssertNil(Self.publishedSnapshots.last?.role)

    fixture.element = makeFocusedUIElement(roleValue: "AXButton" as CFString)
    monitor.refreshIfPollingNeedsSnapshot()
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 2)
    XCTAssertEqual(Self.publishedSnapshots.last?.role, "AXButton")
  }

  func testApplicationSwitchPreemptsRetryAndDelayedRefreshReadsCurrentState() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor)

    monitor.refreshIfPollingNeedsSnapshot()
    XCTAssertEqual(fixture.snapshotReadCount, 2)

    fixture.application = nil
    fixture.element = nil
    fixture.processIdentifiers = PQRSOSXAccessibility.FrontmostProcessIdentifiers(
      axPid: nil,
      workspacePid: nil
    )
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 3)
    XCTAssertNil(Self.publishedSnapshots.last?.processIdentifier)

    // Simulate a delayed notification from the observer that belonged to the
    // previous frontmost application. It may request another refresh, but the
    // refresh must read the current state and must not restore the old retry.
    monitor.requestRefresh(force: false)
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 4)
    XCTAssertNil(Self.publishedSnapshots.last?.processIdentifier)
  }

  func testInactivePollingPerformsNoAcquisition() {
    let fixture = MonitorPollingFixture()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }

    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.processIdentifierReadCount, 0)
    XCTAssertEqual(fixture.snapshotReadCount, 0)
    XCTAssertEqual(fixture.lightweightGeometryReadCount, 0)
  }

  func testFocusedUIElementDisabledDoesNotStartRoleRecoveryPolling() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor, monitoringOptions: [.focusedWindow])

    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.snapshotReadCount, 1)
  }

  func testFocusedWindowDisabledDoesNotPollWindowGeometry() {
    let fixture = MonitorPollingFixture()
    fixture.element = makeFocusedUIElement(
      roleValue: "AXButton" as CFString,
      windowGeometry: geometry(x: 10)
    )
    fixture.lightweightGeometry = geometry(x: 20)
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor, monitoringOptions: [.focusedUIElement])

    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(fixture.lightweightGeometryReadCount, 0)
    XCTAssertEqual(fixture.snapshotReadCount, 1)
  }

  func testStoppedPollingDoesNotAcquireAndRestartHasAFreshBudget() {
    let fixture = MonitorPollingFixture()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }
    start(monitor)
    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      monitor.refreshIfPollingNeedsSnapshot()
    }
    monitor.unsetCallback(generation: 0)
    let processReadsBeforeStop = fixture.processIdentifierReadCount
    let snapshotReadsBeforeStop = fixture.snapshotReadCount

    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      monitor.refreshIfPollingNeedsSnapshot()
    }
    XCTAssertEqual(fixture.processIdentifierReadCount, processReadsBeforeStop)
    XCTAssertEqual(fixture.snapshotReadCount, snapshotReadsBeforeStop)

    start(monitor)
    for _ in 0..<focusedUIElementRoleRecoveryMaxPolls {
      monitor.refreshIfPollingNeedsSnapshot()
    }
    monitor.refreshIfPollingNeedsSnapshot()

    XCTAssertEqual(
      fixture.snapshotReadCount, snapshotReadsBeforeStop + 1 + focusedUIElementRoleRecoveryMaxPolls)
  }

  func testSetMonitoringOptionsRebuildsMonitoringWithNewOptions() {
    let fixture = MonitorPollingFixture()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 42) }

    start(monitor, monitoringOptions: [.focusedUIElement], generation: 42)
    monitor.setMonitoringOptions([.focusedWindow], generation: 42)

    XCTAssertEqual(
      fixture.snapshotMonitoringOptions,
      [.focusedUIElement, .focusedWindow]
    )
    XCTAssertEqual(
      fixture.observationControllerMonitoringOptions,
      [.focusedUIElement, .focusedWindow]
    )
  }

  func testSetMonitoringOptionsDoesNothingWhileInactive() {
    let fixture = MonitorPollingFixture()
    let monitor = fixture.makeMonitor()

    start(monitor, monitoringOptions: [.focusedUIElement])
    monitor.unsetCallback(generation: 0)
    monitor.setMonitoringOptions([.focusedWindow], generation: 0)

    XCTAssertEqual(fixture.snapshotMonitoringOptions, [.focusedUIElement])
    XCTAssertEqual(fixture.observationControllerMonitoringOptions, [.focusedUIElement])
  }

  func testSetMonitoringOptionsDoesNothingWhenOptionsAreUnchanged() {
    let fixture = MonitorPollingFixture()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 0) }

    start(monitor, monitoringOptions: [.focusedUIElement])
    monitor.setMonitoringOptions([.focusedUIElement], generation: 0)

    XCTAssertEqual(fixture.snapshotMonitoringOptions, [.focusedUIElement])
    XCTAssertEqual(fixture.observationControllerMonitoringOptions, [.focusedUIElement])
  }

  func testOperationsFromStaleGenerationDoNotAffectCurrentMonitor() {
    let fixture = MonitorPollingFixture()
    let monitor = fixture.makeMonitor()
    defer { monitor.unsetCallback(generation: 2) }

    start(monitor, monitoringOptions: [.focusedUIElement], generation: 2)

    monitor.setMonitoringOptions([.focusedWindow], generation: 1)
    monitor.trigger(generation: 1)
    monitor.unsetCallback(generation: 1)

    // The current generation remains active with its original configuration.
    monitor.trigger(generation: 2)

    XCTAssertEqual(
      fixture.snapshotMonitoringOptions,
      [.focusedUIElement, .focusedUIElement]
    )
    XCTAssertEqual(fixture.observationControllerMonitoringOptions, [.focusedUIElement])
  }

  private func geometry(x: Double) -> WindowGeometry {
    WindowGeometry(
      position: WindowPosition(x: x, y: 0), size: WindowSize(width: 2 * x, height: 100))
  }

  private func start(
    _ monitor: PQRSOSXAccessibility.Monitor,
    monitoringOptions: AccessibilityMonitoringOptions = [
      .frontmostApplication, .focusedUIElement, .focusedWindow,
    ],
    generation: UInt64 = 0
  ) {
    Self.publishedSnapshots = []
    monitor.setCallback(
      { _, snapshot in
        guard let value = snapshot?.pointee else {
          return
        }
        MainActor.assumeIsolated {
          MonitorPollingRecoveryTests.publishedSnapshots.append(
            MonitorPollingRecoveryTests.PublishedSnapshot(
              processIdentifier: value.pid == 0 ? nil : value.pid,
              role: value.role.map { String(cString: $0) },
              windowTitle: value.window_title.map { String(cString: $0) },
              x: value.has_window_position != 0 ? value.window_position_x : nil,
              width: value.has_window_size != 0 ? value.window_size_width : nil
            )
          )
        }
      }, monitoringOptions: monitoringOptions, generation: generation)
    monitor.trigger(generation: generation)
  }
}
