// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import XCTest

final class FrontmostProcessIdentifierObservationsTests: XCTestCase {
  // An unbundled GUI application may update only Workspace. Verify that the
  // newer Workspace generation replaces the stale AX application.
  func testWorkspaceChangeDetectsUnbundledGUIApplication() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 100)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .workspace
    )
    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 200)),
      changed: true,
      processIdentifier: 200,
      detectionSource: .workspace
    )
  }

  // A transient system UI such as Spotlight may update only AX. Verify that the
  // newer AX generation replaces the stale Workspace application.
  func testAXChangeDetectsTransientSystemUI() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: 200, workspacePid: 100)),
      changed: true,
      processIdentifier: 200,
      detectionSource: .axObserver
    )
  }

  // On the first observation both sources have the same generation. Verify that
  // an initial disagreement uses AX as the documented tie-breaker.
  func testSameGenerationPrefersAX() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 200)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .axObserver
    )
  }

  // After an AX-only transition, Workspace may catch up to the same PID. Verify
  // that agreement reclassifies the application as Workspace-detected.
  func testSourcesConvergeOnWorkspaceApplication() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    _ = observations.observe(.init(axPid: 200, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: 200, workspacePid: 200)),
      changed: true,
      processIdentifier: 200,
      detectionSource: .workspace
    )
  }

  // Stable but disagreeing sources must not repeatedly request a refresh. Verify
  // that only a PID change sets the changed flag.
  func testUnchangedSourcesDoNotRequestRefresh() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 200))
    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 200)),
      changed: false,
      processIdentifier: 100,
      detectionSource: .axObserver
    )
  }

  // A preferred source can temporarily report PID 0 or nil. Verify that PID 0
  // falls back to the other valid source and two nil values resolve to none.
  func testInvalidPreferredPIDFallsBackToOtherSource() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 0)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .axObserver
    )
    assertResolution(
      observations.observe(.init(axPid: nil, workspacePid: nil)),
      changed: true,
      processIdentifier: nil,
      detectionSource: .none
    )
  }

  // When both sources initially report the same PID, no tie-break is necessary.
  // Verify that the shared PID is classified as Workspace-detected.
  func testInitialAgreementUsesWorkspaceDetectionSource() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 100)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .workspace
    )
  }

  // Some applications are visible only through AX. Verify that a valid AX PID
  // is selected and classified for AXObserver management when Workspace is nil.
  func testOnlyAXProcessIdentifierIsAvailable() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: nil)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .axObserver
    )
  }

  // AX can temporarily provide no focused application. Verify that a valid
  // Workspace PID is used when it is the only available source.
  func testOnlyWorkspaceProcessIdentifierIsAvailable() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    assertResolution(
      observations.observe(.init(axPid: nil, workspacePid: 100)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .workspace
    )
  }

  // A normal application switch can update both sources during one observation.
  // Verify that equal new PIDs resolve directly to Workspace detection.
  func testBothSourcesChangeTogether() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: 200, workspacePid: 200)),
      changed: true,
      processIdentifier: 200,
      detectionSource: .workspace
    )
  }

  // If both sources change to different PIDs in one observation, recency cannot
  // distinguish them. Verify that the normal AX tie-break still applies.
  func testBothSourcesChangeToDifferentPIDsTogether() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: 200, workspacePid: 300)),
      changed: true,
      processIdentifier: 200,
      detectionSource: .axObserver
    )
  }

  // AX may be the newer source but temporarily lose its PID. Verify that the
  // valid Workspace PID is used as the fallback.
  func testInvalidAXPreferenceFallsBackToWorkspace() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: nil, workspacePid: 100)),
      changed: true,
      processIdentifier: 100,
      detectionSource: .workspace
    )
  }

  // Once Workspace has the newer generation, repeated observations must retain
  // that choice without reporting another change.
  func testWorkspacePreferencePersistsWhileSourcesRemainUnchanged() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    _ = observations.observe(.init(axPid: 100, workspacePid: 200))
    assertResolution(
      observations.observe(.init(axPid: 100, workspacePid: 200)),
      changed: false,
      processIdentifier: 200,
      detectionSource: .workspace
    )
  }

  // Once AX has the newer generation, repeated observations must retain that
  // choice without reporting another change.
  func testAXPreferencePersistsWhileSourcesRemainUnchanged() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    _ = observations.observe(.init(axPid: 200, workspacePid: 100))
    assertResolution(
      observations.observe(.init(axPid: 200, workspacePid: 100)),
      changed: false,
      processIdentifier: 200,
      detectionSource: .axObserver
    )
  }

  // Observer registration needs both raw source PIDs when AX is selected. Verify
  // that resolution preserves them instead of returning only the selected PID.
  func testResolutionPreservesSourceProcessIdentifiers() {
    var observations = PQRSOSXAccessibility.FrontmostProcessIdentifierObservations()

    _ = observations.observe(.init(axPid: 100, workspacePid: 100))
    let result = observations.observe(.init(axPid: 200, workspacePid: 100))

    XCTAssertEqual(result.resolution.sourceProcessIdentifiers.axPid, 200)
    XCTAssertEqual(result.resolution.sourceProcessIdentifiers.workspacePid, 100)
  }

  private func assertResolution(
    _ result: (
      changed: Bool,
      resolution: PQRSOSXAccessibility.FrontmostProcessIdentifierResolution
    ),
    changed: Bool,
    processIdentifier: pid_t?,
    detectionSource: DetectionSource,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(result.changed, changed, file: file, line: line)
    XCTAssertEqual(
      result.resolution.processIdentifier,
      processIdentifier,
      file: file,
      line: line
    )
    XCTAssertEqual(
      result.resolution.detectionSource,
      detectionSource,
      file: file,
      line: line
    )
  }
}
