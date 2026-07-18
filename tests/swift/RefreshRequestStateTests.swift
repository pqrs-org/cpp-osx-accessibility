// (C) Copyright Takayama Fumihiko 2026.
// Distributed under the Boost Software License, Version 1.0.
// (See https://www.boost.org/LICENSE_1_0.txt)

import XCTest

final class RefreshRequestStateTests: XCTestCase {
  // The first request starts the evaluation loop and is returned as pending.
  func testFirstRequestStartsEvaluationLoop() {
    var state = PQRSOSXAccessibility.RefreshRequestState()

    XCTAssertTrue(state.request(force: false))
    XCTAssertEqual(state.takePendingForce(), false)
    XCTAssertNil(state.takePendingForce())
  }

  // A request made while evaluation is in progress must not start a recursive
  // loop. It remains pending for the current loop to consume.
  func testReentrantRequestIsConsumedByCurrentLoop() {
    var state = PQRSOSXAccessibility.RefreshRequestState()

    XCTAssertTrue(state.request(force: false))
    XCTAssertEqual(state.takePendingForce(), false)
    XCTAssertFalse(state.request(force: false))
    XCTAssertEqual(state.takePendingForce(), false)
    XCTAssertNil(state.takePendingForce())
  }

  // Multiple pending requests are coalesced. If any request is forced, the next
  // evaluation must preserve force=true.
  func testPendingForceValuesAreCombinedWithLogicalOR() {
    var state = PQRSOSXAccessibility.RefreshRequestState()

    XCTAssertTrue(state.request(force: false))
    XCTAssertFalse(state.request(force: true))
    XCTAssertFalse(state.request(force: false))
    XCTAssertEqual(state.takePendingForce(), true)
    XCTAssertNil(state.takePendingForce())
  }

  // A forced reentrant request belongs to the next evaluation rather than the
  // evaluation that has already consumed its force value.
  func testReentrantForceIsConsumedByNextEvaluation() {
    var state = PQRSOSXAccessibility.RefreshRequestState()

    XCTAssertTrue(state.request(force: false))
    XCTAssertEqual(state.takePendingForce(), false)
    XCTAssertFalse(state.request(force: true))
    XCTAssertEqual(state.takePendingForce(), true)
    XCTAssertNil(state.takePendingForce())
  }

  // Draining the queue releases the in-flight state, allowing a later request
  // to start a fresh evaluation loop.
  func testRequestAfterDrainStartsNewEvaluationLoop() {
    var state = PQRSOSXAccessibility.RefreshRequestState()

    XCTAssertTrue(state.request(force: false))
    XCTAssertEqual(state.takePendingForce(), false)
    XCTAssertNil(state.takePendingForce())

    XCTAssertTrue(state.request(force: true))
    XCTAssertEqual(state.takePendingForce(), true)
    XCTAssertNil(state.takePendingForce())
  }
}
