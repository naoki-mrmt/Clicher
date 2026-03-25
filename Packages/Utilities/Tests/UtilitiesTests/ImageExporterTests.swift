import Testing
import CoreGraphics
import Foundation
@testable import Utilities
import SharedModels

@Suite("ImageExporter Tests")
struct ImageExporterTests {
    /// テスト用のダミー画像を生成
    private func makeDummyImage() -> CGImage {
        let width = 100
        let height = 100
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ), let image = ctx.makeImage() else {
            fatalError("テスト用画像の生成に失敗")
        }
        return image
    }

    @Test("saveToFile creates a file at the specified directory")
    func saveToFile() throws {
        let image = makeDummyImage()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = ImageExporter.saveToFile(image, format: .png, directory: tempDir)
        #expect(url != nil)
        if let url {
            #expect(FileManager.default.fileExists(atPath: url.path))
            #expect(url.pathExtension == "png")
        }
    }

    @Test("generateFileName produces correct format")
    func fileNameFormat() {
        let name = ImageExporter.generateFileName(format: .png)
        #expect(name.hasPrefix("Clicher_"))
        #expect(name.hasSuffix(".png"))
    }

    @Test("generateFileName for jpeg has correct extension")
    func fileNameFormatJpeg() {
        let name = ImageExporter.generateFileName(format: .jpeg)
        #expect(name.hasSuffix(".jpeg"))
    }
}
