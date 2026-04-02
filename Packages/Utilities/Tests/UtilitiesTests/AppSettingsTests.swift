import Testing
@testable import Utilities
@testable import SharedModels

@Suite("AppSettings Tests")
struct AppSettingsTests {
    @Test("default values are correct")
    @MainActor func defaultValues() {
        let settings = AppSettings()
        #expect(settings.fileNamePattern == .dateTime)
        #expect(settings.imageFormat == .png)
        #expect(settings.captureRetina == true)
        #expect(settings.overlayPosition == .bottomRight)
        #expect(settings.overlayAutoCloseSeconds == 5)
        #expect(settings.launchAtLogin == false)
    }

    @Test("hotkey defaults to Cmd+Shift+A")
    @MainActor func hotkeyDefaults() {
        let settings = AppSettings()
        #expect(settings.hotkeyKeyCode == 0) // kVK_ANSI_A
        #expect(settings.hotkeyModifiers != 0) // Command+Shift flags
    }

    @Test("save directory has a valid default")
    @MainActor func saveDirectoryDefault() {
        let settings = AppSettings()
        #expect(!settings.saveDirectory.path.isEmpty)
    }
}
