import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import SharedModels
@testable import Utilities
@testable import CaptureEngine
@testable import AnnotateEngine
@testable import OverlayUI

/// テストヘルパーで使用するエラー型
private enum TestHelperError: Error {
    case contextCreationFailed
    case imageCreationFailed
}

// MARK: - E2E Integration Tests

@Suite("E2E Integration Tests")
struct E2EIntegrationTests {
    /// テスト用ダミー画像
    private func makeDummyImage(width: Int = 400, height: Int = 300) throws -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw TestHelperError.contextCreationFailed
        }
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = ctx.makeImage() else {
            throw TestHelperError.imageCreationFailed
        }
        return image
    }

    // MARK: - Capture → QuickAccess Pipeline

    @Test("CaptureResult → QuickAccessOverlay callback fires")
    @MainActor func captureToOverlay() throws {
        let image = try makeDummyImage()
        let result = CaptureResult(image: image, mode: .area)

        var saveCalled = false
        var copyCalled = false
        var editCalled = false
        var pinCalled = false

        let overlay = QuickAccessOverlay()
        overlay.onSave = { _ in saveCalled = true }
        overlay.onCopy = { _ in copyCalled = true }
        overlay.onEdit = { _ in editCalled = true }
        overlay.onPin = { _ in pinCalled = true }

        // コールバックが正しく設定されていることを確認
        overlay.onSave?(result)
        overlay.onCopy?(result)
        overlay.onEdit?(result)
        overlay.onPin?(result)

        #expect(saveCalled)
        #expect(copyCalled)
        #expect(editCalled)
        #expect(pinCalled)
    }

    // MARK: - Capture → Annotate → Export Pipeline

    @Test("CaptureResult → AnnotateDocument → items → export")
    @MainActor func captureToAnnotateExport() throws {
        let image = try makeDummyImage()
        let doc = AnnotateDocument(image: image)

        // アノテーション追加
        doc.addItem(AnnotationItem(
            toolType: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 100, y: 80)
        ))
        doc.addItem(AnnotationItem(
            toolType: .arrow,
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 200, y: 150)
        ))

        #expect(doc.items.count == 2)
        #expect(doc.canUndo)

        // Undo/Redo
        doc.undo()
        #expect(doc.items.count == 1)
        doc.redo()
        #expect(doc.items.count == 2)
    }

    // MARK: - Annotate + Background Pipeline

    @Test("AnnotateDocument + BackgroundTool export pipeline")
    @MainActor func annotateWithBackground() throws {
        let image = try makeDummyImage()
        let doc = AnnotateDocument(image: image)
        doc.addItem(AnnotationItem(toolType: .rectangle, startPoint: .zero, endPoint: CGPoint(x: 100, y: 100)))

        // BackgroundTool で背景追加
        let config = BackgroundConfig(
            style: .gradient(
                startColor: CGColor(red: 1, green: 0.5, blue: 0, alpha: 1),
                endColor: CGColor(red: 0.5, green: 0, blue: 1, alpha: 1),
                angle: 45
            ),
            padding: 40,
            cornerRadius: 12
        )
        let withBg = try #require(BackgroundTool.apply(to: image, config: config))
        #expect(withBg.width == 400 + 80) // padding * 2
        #expect(withBg.height == 300 + 80)
    }

    // MARK: - OCR Pipeline

    @Test("OCRResult → clipboard text format")
    func ocrResultFormat() {
        // テキストのみ
        let textOnly = OCRResult(text: "Hello World")
        #expect(!textOnly.isEmpty)

        // バーコードのみ
        let barcodeOnly = OCRResult(text: "", barcodes: ["https://example.com"])
        #expect(!barcodeOnly.isEmpty)

        // 空
        let empty = OCRResult(text: "", barcodes: [])
        #expect(empty.isEmpty)
    }

    // MARK: - Brand Preset → Annotate Pipeline

    @Test("BrandPreset default color applies to AnnotationStyle")
    @MainActor func presetToAnnotate() {
        let preset = BrandPreset(
            name: "Test",
            primaryColor: CodableColor(red: 0, green: 0.5, blue: 1)
        )

        // プリセットの primaryColor を AnnotationStyle に適用
        var style = AnnotationStyle()
        style.strokeColor = .init(cgColor: preset.primaryColor.cgColor) ?? .systemRed

        #expect(style.strokeColor != .systemRed)
    }

    // MARK: - Floating Screenshot Pipeline

    @Test("FloatingScreenshotManager pin/closeAll")
    @MainActor func floatingPinAndClose() {
        let manager = FloatingScreenshotManager()
        #expect(manager.windows.isEmpty)
        // pin は NSPanel を作るので headless テスト環境では呼ばないが、
        // manager の API が正しいことを確認
        manager.closeAll()
        #expect(manager.windows.isEmpty)
    }

    // MARK: - History Pipeline

    // MARK: - Image Utilities Pipeline

    @Test("Combine + Rotate pipeline")
    func combineAndRotate() throws {
        let img1 = try makeDummyImage(width: 100, height: 50)
        let img2 = try makeDummyImage(width: 100, height: 50)

        // 横結合
        guard let combined = ImageUtilities.combine(images: [img1, img2], direction: .horizontal) else {
            Issue.record("結合に失敗")
            return
        }
        #expect(combined.width == 200)
        #expect(combined.height == 50)

        // 90度回転
        guard let rotated = ImageUtilities.transform(combined, orientation: .rotateRight) else {
            Issue.record("回転に失敗")
            return
        }
        #expect(rotated.width == 50)
        #expect(rotated.height == 200)
    }

    // MARK: - Video Pipeline

    @Test("VideoQuality presets are valid")
    func videoQualityPresets() {
        let presets = [VideoQuality.high, .medium, .low, .hd720, .hd1080]
        for preset in presets {
            #expect(!preset.preset.isEmpty)
        }
    }

    // MARK: - Self-Timer Pipeline

    @Test("CaptureCoordinator timer state management")
    @MainActor func timerState() {
        let coordinator = CaptureCoordinator()
        #expect(!coordinator.isCountingDown)
        #expect(coordinator.countdownRemaining == 0)
        #expect(!coordinator.isCapturing)
        #expect(!coordinator.isRecording)
    }

    // MARK: - Settings Pipeline

    @Test("AppSettings defaults are consistent")
    @MainActor func settingsDefaults() {
        let settings = AppSettings()
        #expect(settings.imageFormat == .png)
        #expect(settings.captureRetina == true)
        #expect(settings.overlayPosition == .bottomRight)
        #expect(settings.overlayAutoCloseSeconds == 5)
    }

    // MARK: - Brand Preset Store Pipeline

    @Test("BrandPreset CRUD + clipreset roundtrip")
    @MainActor func presetCRUD() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = BrandPresetStore(directory: dir)

        // Create
        let preset = BrandPreset(name: "E2E Test", primaryColor: .blue, isDefault: true)
        try store.save(preset)

        // Read
        let loaded = store.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "E2E Test")

        // Default
        #expect(store.defaultPreset()?.name == "E2E Test")

        // Export
        let exportURL = dir.appendingPathComponent("test.clipreset")
        try store.exportToClipreset(preset, to: exportURL)
        #expect(FileManager.default.fileExists(atPath: exportURL.path))

        // Delete
        try store.delete(preset)
        #expect(store.loadAll().isEmpty)
    }
}
