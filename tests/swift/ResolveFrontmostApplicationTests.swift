// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import AppKit
import XCTest

@MainActor
final class ResolveFrontmostApplicationTests: XCTestCase {
  // A Workspace resolution registers only the Workspace PID and preserves a
  // cached application whose PID and detection source still match.
  func testWorkspaceResolution() {
    let runningApplication = NSRunningApplication.current
    let pid = runningApplication.processIdentifier
    let cachedApplication = FrontmostApplication(
      runningApplication,
      detectionSource: .workspace
    )
    var registrations: [(pid_t?, DetectionSource)] = []

    let result = resolveFrontmostApplication(
      cachedApplication: cachedApplication,
      workspaceFrontmostApplication: runningApplication,
      resolution: .init(
        processIdentifier: pid,
        detectionSource: .workspace,
        sourceProcessIdentifiers: .init(axPid: pid, workspacePid: pid)
      ),
      handleProcessIdentifier: { registrations.append(($0, $1)) }
    )

    XCTAssertEqual(result, cachedApplication)
    assertRegistrations(
      registrations,
      expected: [(pid, .workspace)]
    )
  }

  // An AX resolution registers the Workspace-known PID first and the selected
  // AX-only PID second so both observation lifecycles remain managed.
  func testAXObserverResolutionRegistersBothSources() {
    let runningApplication = NSRunningApplication.current
    let axPid = runningApplication.processIdentifier
    let workspacePid = axPid + 1
    let cachedApplication = FrontmostApplication(
      runningApplication,
      detectionSource: .axObserver
    )
    var registrations: [(pid_t?, DetectionSource)] = []

    let result = resolveFrontmostApplication(
      cachedApplication: cachedApplication,
      workspaceFrontmostApplication: nil,
      resolution: .init(
        processIdentifier: axPid,
        detectionSource: .axObserver,
        sourceProcessIdentifiers: .init(axPid: axPid, workspacePid: workspacePid)
      ),
      handleProcessIdentifier: { registrations.append(($0, $1)) }
    )

    XCTAssertEqual(result, cachedApplication)
    assertRegistrations(
      registrations,
      expected: [
        (workspacePid, .workspace),
        (axPid, .axObserver),
      ]
    )
  }

  // A changed detection source must rebuild the application even when its PID
  // is unchanged, ensuring that the emitted snapshot reports the new source.
  func testDetectionSourceChangeRebuildsApplication() {
    let runningApplication = NSRunningApplication.current
    let pid = runningApplication.processIdentifier
    let cachedApplication = FrontmostApplication(
      runningApplication,
      detectionSource: .workspace
    )

    let result = resolveFrontmostApplication(
      cachedApplication: cachedApplication,
      workspaceFrontmostApplication: runningApplication,
      resolution: .init(
        processIdentifier: pid,
        detectionSource: .axObserver,
        sourceProcessIdentifiers: .init(axPid: pid, workspacePid: nil)
      ),
      handleProcessIdentifier: { _, _ in }
    )

    XCTAssertEqual(result?.detectionSource, .axObserver)
    XCTAssertNotEqual(result, cachedApplication)
  }

  // With no valid PID, no process is registered and the returned application
  // contains no process metadata.
  func testNoneResolution() {
    var registrations: [(pid_t?, DetectionSource)] = []

    let result = resolveFrontmostApplication(
      cachedApplication: nil,
      workspaceFrontmostApplication: nil,
      resolution: .init(
        processIdentifier: nil,
        detectionSource: .none,
        sourceProcessIdentifiers: .init(axPid: nil, workspacePid: nil)
      ),
      handleProcessIdentifier: { registrations.append(($0, $1)) }
    )

    XCTAssertTrue(registrations.isEmpty)
    XCTAssertNil(result?.processIdentifier)
    XCTAssertEqual(result?.detectionSource, DetectionSource.none)
  }

  private func assertRegistrations(
    _ actual: [(pid_t?, DetectionSource)],
    expected: [(pid_t?, DetectionSource)],
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(actual.count, expected.count, file: file, line: line)
    for (actual, expected) in zip(actual, expected) {
      XCTAssertEqual(actual.0, expected.0, file: file, line: line)
      XCTAssertEqual(actual.1, expected.1, file: file, line: line)
    }
  }
}
