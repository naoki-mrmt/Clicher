import Testing
@testable import Utilities
@testable import SharedModels

@Suite("AppSettings Tests")
struct AppSettingsTests {
    @Test("default values are correct")
    @MainActor func defaultValues() {
        // UserDefaults に何も設定されていない状態でのデフォルト値を確認
        let settings = AppSettings()
        #expect(settings.fileNamePattern == .dateTime)
        #expect(settings.imageFormat == .png)
        #expect(settings.captureRetina == true)
        #expect(settings.overlayPosition == .bottomRight)
        #expect(settings.overlayAutoCloseSeconds == 5)
        #expect(settings.launchAtLogin == false)
    }
}
