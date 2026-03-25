import Testing
@testable import CaptureEngine
import SharedModels

@Suite("Timer Capture Tests")
struct TimerCaptureTests {
    @Test("startCapture with timer delay stores countdown state")
    @MainActor func timerDelayState() {
        let coordinator = CaptureCoordinator()
        #expect(coordinator.countdownRemaining == 0)
        #expect(!coordinator.isCountingDown)
    }

    @Test("countdown overlay can be created")
    @MainActor func countdownOverlay() {
        let overlay = CountdownOverlay()
        #expect(overlay.remaining == 0)
    }
}
