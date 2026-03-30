import Testing
@testable import CaptureEngine

@Suite("ScreenRecording Tests")
struct ScreenRecordingTests {
    @Test("ScreenRecordingSession initial state")
    @MainActor func initialState() {
        let session = ScreenRecordingSession()
        #expect(!session.isRecording)
        #expect(session.duration == 0)
    }

    @Test("CaptureCoordinator recording state")
    @MainActor func coordinatorRecordingState() {
        let coordinator = CaptureCoordinator()
        #expect(!coordinator.isRecording)
        #expect(coordinator.recordingSession == nil)
    }
}
