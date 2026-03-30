import Testing
import CoreGraphics
@testable import OverlayUI
import SharedModels

@Suite("FloatingScreenshot Tests")
struct FloatingScreenshotTests {
    @Test("FloatingScreenshotManager starts empty")
    @MainActor func managerInit() {
        let manager = FloatingScreenshotManager()
        #expect(manager.windows.isEmpty)
    }

    @Test("FloatingScreenshotConfig has correct defaults")
    func configDefaults() {
        let config = FloatingScreenshotConfig()
        #expect(config.opacity == 1.0)
        #expect(config.isClickThrough == false)
        #expect(config.isAlwaysOnTop == true)
    }
}
