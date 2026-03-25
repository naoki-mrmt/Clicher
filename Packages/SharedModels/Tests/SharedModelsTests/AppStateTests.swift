import Testing
@testable import SharedModels

@Suite("AppState Tests")
struct AppStateTests {
    @Test("initial values are correct")
    @MainActor func initialValues() {
        let state = AppState()
        #expect(state.selectedCaptureMode == .area)
        #expect(state.isHUDVisible == false)
        #expect(state.isPermissionGuideVisible == false)
        #expect(state.hasScreenRecordingPermission == false)
        #expect(state.hasAccessibilityPermission == false)
        #expect(state.timerDelay == .none)
        #expect(state.showCrosshair == true)
        #expect(state.showMagnifier == true)
    }
}
