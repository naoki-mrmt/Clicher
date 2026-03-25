import Testing
@testable import OverlayUI
import SharedModels

@Suite("OverlayUI Tests")
struct OverlayUITests {
    @Test("QuickAccessOverlay can be instantiated")
    @MainActor func quickAccessInit() {
        let overlay = QuickAccessOverlay()
        // Callbacks should be nil by default
        #expect(overlay.onSave == nil)
        #expect(overlay.onCopy == nil)
        #expect(overlay.onEdit == nil)
    }

    @Test("CaptureHUDWindow can be instantiated")
    @MainActor func hudWindowInit() {
        let state = AppState()
        let hud = CaptureHUDWindow(appState: state)
        #expect(hud.onModeSelected == nil)
    }
}
