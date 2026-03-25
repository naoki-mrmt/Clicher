import Testing
@testable import SharedModels

@Suite("CaptureMode Tests")
struct CaptureModeTests {
    @Test("availableModes returns only area, window, fullscreen")
    func availableModes() {
        let modes = CaptureMode.availableModes
        #expect(modes == [.area, .window, .fullscreen])
    }

    @Test("all cases have non-empty labels")
    func labelsExist() {
        for mode in CaptureMode.allCases {
            #expect(!mode.label.isEmpty)
        }
    }

    @Test("all cases have non-empty systemImage")
    func systemImagesExist() {
        for mode in CaptureMode.allCases {
            #expect(!mode.systemImage.isEmpty)
        }
    }

    @Test("shortcutKey matches rawValue")
    func shortcutKeys() {
        for mode in CaptureMode.allCases {
            #expect(mode.shortcutKey == "\(mode.rawValue)")
        }
    }

    @Test("scroll, ocr, recording are unavailable")
    func unavailableModes() {
        #expect(!CaptureMode.scroll.isAvailable)
        #expect(!CaptureMode.ocr.isAvailable)
        #expect(!CaptureMode.recording.isAvailable)
    }

    @Test("area, window, fullscreen are available")
    func availableModesFlag() {
        #expect(CaptureMode.area.isAvailable)
        #expect(CaptureMode.window.isAvailable)
        #expect(CaptureMode.fullscreen.isAvailable)
    }
}
