import Testing
import CoreGraphics
@testable import AnnotateEngine
import SharedModels

/// テストヘルパーで使用するエラー型
private enum TestHelperError: Error {
    case contextCreationFailed
    case imageCreationFailed
}

@Suite("AnnotateDocument Tests")
struct AnnotateDocumentTests {
    /// テスト用ダミー画像
    private func makeDummyImage() throws -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: 100, height: 100,
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

    @Test("initial state has no items")
    @MainActor func initialState() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        #expect(doc.items.isEmpty)
        #expect(!doc.canUndo)
        #expect(!doc.canRedo)
        #expect(doc.currentTool == .arrow)
        #expect(doc.nextCounterNumber == 1)
        #expect(doc.cropRect == nil)
    }

    @Test("addItem appends and enables undo")
    @MainActor func addItem() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        let item = AnnotationItem(toolType: .rectangle)
        doc.addItem(item)
        #expect(doc.items.count == 1)
        #expect(doc.canUndo)
        #expect(!doc.canRedo)
    }

    @Test("undo restores previous state")
    @MainActor func undo() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        doc.addItem(AnnotationItem(toolType: .rectangle))
        doc.undo()
        #expect(doc.items.isEmpty)
        #expect(!doc.canUndo)
        #expect(doc.canRedo)
    }

    @Test("redo restores next state")
    @MainActor func redo() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        doc.addItem(AnnotationItem(toolType: .rectangle))
        doc.undo()
        doc.redo()
        #expect(doc.items.count == 1)
        #expect(doc.canUndo)
        #expect(!doc.canRedo)
    }

    @Test("undo stack limited to 50")
    @MainActor func undoStackLimit() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        for _ in 0..<60 {
            doc.addItem(AnnotationItem(toolType: .line))
        }
        // After 60 adds, undo stack should be capped at 50
        var undoCount = 0
        while doc.canUndo {
            doc.undo()
            undoCount += 1
        }
        #expect(undoCount == 50)
    }

    @Test("addItem clears redo stack")
    @MainActor func addClearsRedo() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        doc.addItem(AnnotationItem(toolType: .rectangle))
        doc.undo()
        #expect(doc.canRedo)
        doc.addItem(AnnotationItem(toolType: .ellipse))
        #expect(!doc.canRedo)
    }

    @Test("removeLastItem removes and enables undo")
    @MainActor func removeLast() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        doc.addItem(AnnotationItem(toolType: .rectangle))
        doc.addItem(AnnotationItem(toolType: .ellipse))
        doc.removeLastItem()
        #expect(doc.items.count == 1)
    }

    @Test("counter number increments")
    @MainActor func counterNumber() throws {
        let doc = AnnotateDocument(image: try makeDummyImage())
        #expect(doc.nextCounterNumber == 1)
        doc.nextCounterNumber += 1
        #expect(doc.nextCounterNumber == 2)
    }
}
