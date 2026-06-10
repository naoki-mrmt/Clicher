import Testing
@testable import SharedModels

@Suite("CaptureMode Tests")
struct CaptureModeTests {
    @Test("all cases have non-empty labels", arguments: CaptureMode.allCases)
    func labelsExist(mode: CaptureMode) {
        #expect(!mode.label.isEmpty)
    }

    @Test("all cases have non-empty systemImage", arguments: CaptureMode.allCases)
    func systemImagesExist(mode: CaptureMode) {
        #expect(!mode.systemImage.isEmpty)
    }

    @Test("shortcutKey matches rawValue", arguments: CaptureMode.allCases)
    func shortcutKeys(mode: CaptureMode) {
        #expect(mode.shortcutKey == "\(mode.rawValue)")
    }
}
