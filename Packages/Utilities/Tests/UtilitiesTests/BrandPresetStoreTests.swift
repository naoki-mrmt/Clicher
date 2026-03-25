import Testing
import Foundation
@testable import Utilities
import SharedModels

@Suite("BrandPresetStore Tests")
struct BrandPresetStoreTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("save and load preset")
    @MainActor func saveAndLoad() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BrandPresetStore(directory: dir)
        let preset = BrandPreset(name: "Test Brand", isDefault: true)

        try store.save(preset)
        let loaded = store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Test Brand")
        #expect(loaded.first?.isDefault == true)
    }

    @Test("delete preset")
    @MainActor func deletePreset() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BrandPresetStore(directory: dir)
        let preset = BrandPreset(name: "To Delete")
        try store.save(preset)
        #expect(store.loadAll().count == 1)

        try store.delete(preset)
        #expect(store.loadAll().isEmpty)
    }

    @Test("defaultPreset returns preset with isDefault=true")
    @MainActor func defaultPreset() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BrandPresetStore(directory: dir)
        try store.save(BrandPreset(name: "Normal"))
        try store.save(BrandPreset(name: "Default", isDefault: true))

        let defaultPreset = store.defaultPreset()
        #expect(defaultPreset?.name == "Default")
    }

    @Test("export and import clipreset")
    @MainActor func exportImport() throws {
        let dir = try makeTempDir()
        let exportDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(at: exportDir)
        }

        let store = BrandPresetStore(directory: dir)
        let preset = BrandPreset(name: "Export Test", primaryColor: .red)

        let exportURL = exportDir.appendingPathComponent("test.clipreset")
        try store.exportToClipreset(preset, to: exportURL)
        #expect(FileManager.default.fileExists(atPath: exportURL.path))

        let imported = try store.importFromClipreset(at: exportURL)
        #expect(imported.name == "Export Test")
        #expect(imported.primaryColor == .red)
    }
}
