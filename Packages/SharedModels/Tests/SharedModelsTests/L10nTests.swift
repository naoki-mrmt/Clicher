import Testing
@testable import SharedModels

@Suite("L10n Localization Tests")
struct L10nTests {
    @Test("Common strings are non-empty")
    func commonStringsNonEmpty() {
        #expect(!L10n.save.isEmpty)
        #expect(!L10n.copy.isEmpty)
        #expect(!L10n.edit.isEmpty)
        #expect(!L10n.delete.isEmpty)
        #expect(!L10n.cancel.isEmpty)
        #expect(!L10n.done.isEmpty)
        #expect(!L10n.settings.isEmpty)
        #expect(!L10n.quit.isEmpty)
    }

    @Test("Capture strings are non-empty")
    func captureStringsNonEmpty() {
        #expect(!L10n.screenshot.isEmpty)
        #expect(!L10n.screenRecording.isEmpty)
        #expect(!L10n.recognizeText.isEmpty)
    }

    @Test("Parameterized strings include value")
    func parameterizedStrings() {
        let saved = L10n.saved("test.png")
        #expect(saved.contains("test.png"))

        let autoClose = L10n.autoCloseSeconds(5)
        #expect(autoClose.contains("5"))
    }

    @Test("Permission strings are non-empty")
    func permissionStringsNonEmpty() {
        #expect(!L10n.permissionsRequired.isEmpty)
        #expect(!L10n.permissionsDescription.isEmpty)
        #expect(!L10n.screenRecordingDesc.isEmpty)
        #expect(!L10n.accessibilityDesc.isEmpty)
        #expect(!L10n.grant.isEmpty)
        #expect(!L10n.granted.isEmpty)
    }

    @Test("Brand preset strings are non-empty")
    func brandStringsNonEmpty() {
        #expect(!L10n.brandPresets.isEmpty)
        #expect(!L10n.brandDescription.isEmpty)
        #expect(!L10n.selectOrAddPreset.isEmpty)
    }
}
