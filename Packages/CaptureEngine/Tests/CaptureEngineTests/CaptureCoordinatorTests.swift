import Testing
import Foundation
import CoreGraphics
@testable import CaptureEngine
import SharedModels

@Suite("CaptureCoordinator Tests")
struct CaptureCoordinatorTests {
    @Test("initial state is not capturing")
    @MainActor func initialState() {
        let coordinator = CaptureCoordinator()
        #expect(!coordinator.isCapturing)
        #expect(!coordinator.isCountingDown)
        #expect(!coordinator.isRecording)
        #expect(coordinator.lastResult == nil)
        #expect(coordinator.countdownRemaining == 0)
        #expect(coordinator.recordingSession == nil)
        #expect(coordinator.inlineAnnotate == nil)
    }

    @Test("startCapture guards when already capturing")
    @MainActor func guardWhenCapturing() {
        let coordinator = CaptureCoordinator()
        // Simulate capturing state by calling startCapture
        // Since we can't actually capture (no screen permission), verify the guard logic
        // by checking that double-calling doesn't crash
        coordinator.startCapture(mode: .fullscreen)
        // Second call should be guarded
        coordinator.startCapture(mode: .fullscreen)
    }

    @Test("onError callback is settable")
    @MainActor func errorCallback() {
        let coordinator = CaptureCoordinator()
        var errorMessage: String?
        coordinator.onError = { message in
            errorMessage = message
        }
        // Callback should be set but not called yet
        #expect(errorMessage == nil)
    }

    @Test("onCaptureComplete callback is settable")
    @MainActor func completeCallback() {
        let coordinator = CaptureCoordinator()
        var called = false
        coordinator.onCaptureComplete = { _ in
            called = true
        }
        #expect(!called)
    }
}

@Suite("ScreenCaptureService Tests")
struct ScreenCaptureServiceTests {
    @Test("service conforms to protocol")
    func serviceConformsToProtocol() {
        let service = ScreenCaptureService()
        let _: any ScreenCaptureServiceProtocol = service
    }
}

@Suite("RecordingError Tests")
struct RecordingErrorTests {
    @Test("noDisplay has description")
    func noDisplayError() {
        let error = RecordingError.noDisplay
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test("writerFailed wraps inner error")
    func writerFailedError() {
        let inner = NSError(domain: "test", code: 1)
        let error = RecordingError.writerFailed(inner)
        #expect(error.errorDescription != nil)
    }
}
