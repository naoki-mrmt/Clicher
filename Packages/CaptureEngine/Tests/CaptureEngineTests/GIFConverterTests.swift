import Testing
@testable import CaptureEngine

@Suite("GIFConverter Tests")
struct GIFConverterTests {
    @Test("GIFError cases exist")
    func errorCases() {
        let errors: [GIFError] = [.noVideoTrack, .cannotCreateDestination, .finalizeFailed]
        #expect(errors.count == 3)
    }

    @Test("ScreenRecordingSession audio settings")
    @MainActor func audioSettings() {
        let session = ScreenRecordingSession()
        #expect(session.capturesSystemAudio == true)
        #expect(session.capturesMicrophone == false)
    }
}
