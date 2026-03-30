import Testing
import Foundation
import CoreGraphics
@testable import Utilities
import SharedModels

/// テストヘルパーで使用するエラー型
private enum TestHelperError: Error {
    case contextCreationFailed
    case imageCreationFailed
}

@Suite("CaptureHistoryStore Tests")
struct CaptureHistoryStoreTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeDummyImage() throws -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: 100, height: 50,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw TestHelperError.contextCreationFailed
        }
        guard let image = ctx.makeImage() else {
            throw TestHelperError.imageCreationFailed
        }
        return image
    }

    @Test("add and retrieve entries")
    @MainActor func addAndRetrieve() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CaptureHistoryStore(directory: dir)
        store.add(image: try makeDummyImage(), mode: .area)
        store.add(image: try makeDummyImage(), mode: .fullscreen)

        let entries = store.allEntries()
        #expect(entries.count == 2)
        #expect(entries.first?.mode == "フルスクリーン") // newest first
    }

    @Test("delete entry")
    @MainActor func deleteEntry() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CaptureHistoryStore(directory: dir)
        store.add(image: try makeDummyImage(), mode: .area)

        let entry = try #require(store.allEntries().first)
        store.delete(entry)
        #expect(store.allEntries().isEmpty)
    }

    @Test("max entries limit")
    @MainActor func maxLimit() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = CaptureHistoryStore(directory: dir, maxEntries: 3)
        for _ in 0..<5 {
            store.add(image: try makeDummyImage(), mode: .area)
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
