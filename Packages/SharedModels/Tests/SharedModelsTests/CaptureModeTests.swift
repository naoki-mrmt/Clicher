import Testing
@testable import SharedModels

@Suite("CaptureMode Tests")
struct CaptureModeTests {
    @Test("availableModes returns all cases")
    func availableModes() {
        let modes = CaptureMode.availableModes
        #expect(modes == CaptureMode.allCases)
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

    @Test("all modes are available")
    func allModesAvailable() {
        for mode in CaptureMode.allCases {
            #expect(mode.isAvailable)
        }
    }
}
