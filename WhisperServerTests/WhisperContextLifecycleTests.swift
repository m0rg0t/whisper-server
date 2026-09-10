import XCTest
@testable import WhisperServer

final class WhisperContextLifecycleTests: XCTestCase {
    func testTimeoutDuringActiveLeaseDoesNotAllowFree() {
        var state = WhisperContextLifecycleState()

        XCTAssertTrue(state.canReleaseForInactivity())

        state.acquire()

        XCTAssertEqual(state.activeUseCount, 1)
        XCTAssertFalse(state.canReleaseForInactivity())
        XCTAssertFalse(state.pendingFree)

        XCTAssertFalse(state.release())
        XCTAssertEqual(state.activeUseCount, 0)
        XCTAssertTrue(state.canReleaseForInactivity())
    }

    func testReinitializationIsDeferredUntilLastLeaseReleases() {
        var state = WhisperContextLifecycleState()

        state.acquire()
        state.acquire()

        XCTAssertFalse(state.requestReinitialization())
        XCTAssertTrue(state.pendingFree)
        XCTAssertEqual(state.activeUseCount, 2)

        XCTAssertFalse(state.release(), "The first release must not free a context still used by another lease")
        XCTAssertTrue(state.pendingFree)
        XCTAssertEqual(state.activeUseCount, 1)

        XCTAssertTrue(state.release(), "The final release must perform the deferred reinitialization free")
        XCTAssertFalse(state.pendingFree)
        XCTAssertEqual(state.activeUseCount, 0)
    }

    func testReleaseBalancesLeaseAfterInferenceFailure() {
        var state = WhisperContextLifecycleState()

        let inferenceSucceeded = runFailingInference(using: &state)

        XCTAssertFalse(inferenceSucceeded)
        XCTAssertEqual(state.activeUseCount, 0, "Failure paths must release the active context lease")
        XCTAssertFalse(state.pendingFree)
        XCTAssertTrue(state.canReleaseForInactivity())
    }

    private func runFailingInference(using state: inout WhisperContextLifecycleState) -> Bool {
        state.acquire()
        defer { _ = state.release() }

        // Simulates whisper_full returning a non-zero status and the caller
        // taking its early-return failure path.
        return false
    }
}
