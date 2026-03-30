import Testing
import Foundation
import CoreGraphics
@testable import Utilities
import SharedModels

@Suite("CaptureHistoryStore Tests")
struct CaptureHistoryStoreTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeDummyImage() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 100, height: 50,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )!
        return ctx.makeImage()!
    }

    @Test("add and retrieve entries")
    @MainActor func addAndRetrieve() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CaptureHistoryStore(directory: dir)
        store.add(image: makeDummyImage(), mode: .area)
        store.add(image: makeDummyImage(), mode: .fullscreen)

        let entries = store.allEntries()
        #expect(entries.count == 2)
        #expect(entries.first?.mode == "フルスクリーン") // newest first
    }

    @Test("delete entry")
    @MainActor func deleteEntry() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CaptureHistoryStore(directory: dir)
        store.add(image: makeDummyImage(), mode: .area)

        let entry = store.allEntries().first!
        store.delete(entry)
        #expect(store.allEntries().isEmpty)
    }

    @Test("max entries limit")
    @MainActor func maxLimit() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CaptureHistoryStore(directory: dir, maxEntries: 3)
        for _ in 0..<5 {
            store.add(image: makeDummyImage(), mode: .area)
        }
        #expect(store.allEntries().count == 3)
    }

    @Test("CaptureHistoryEntry formatted values")
    func entryFormatting() {
        let entry = CaptureHistoryEntry(
            mode: .area,
            width: 1920,
            height: 1080,
            thumbnailPath: "/tmp/test.png"
        )
        #expect(entry.sizeLabel == "1920 × 1080")
        #expect(!entry.formattedDate.isEmpty)
    }
}
