import Testing
@testable import CaptureEngine

@Suite("VideoEditor Tests")
struct VideoEditorTests {
    @Test("VideoQuality presets exist")
    func qualityPresets() {
        #expect(!VideoQuality.high.preset.isEmpty)
        #expect(!VideoQuality.medium.preset.isEmpty)
        #expect(!VideoQuality.low.preset.isEmpty)
        #expect(!VideoQuality.hd720.preset.isEmpty)
        #expect(!VideoQuality.hd1080.preset.isEmpty)
    }

    @Test("VideoInfo formatted size")
    func formattedSize() {
        let info = VideoInfo(duration: 10, size: .zero, fps: 30, hasAudio: true, fileSize: 1_048_576)
        #expect(info.fileSizeFormatted.contains("MB") || info.fileSizeFormatted.contains("1"))
    }

    @Test("VideoEditorError cases exist")
    func errorCases() {
        let errors: [VideoEditorError] = [
            .invalidTimeRange,
            .exporterCreationFailed,
            .exportFailed(nil),
        ]
        #expect(errors.count == 3)
    }
}
