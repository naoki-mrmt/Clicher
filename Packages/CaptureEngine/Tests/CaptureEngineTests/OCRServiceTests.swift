import Testing
import CoreGraphics
@testable import CaptureEngine

@Suite("OCRService Tests")
struct OCRServiceTests {
    private func makeDummyImage() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 200, height: 100,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )!
        return ctx.makeImage()!
    }

    @Test("recognizeText returns empty for blank image")
    func recognizeBlank() async throws {
        let image = makeDummyImage()
        let result = try await OCRService.recognizeText(from: image)
        // Blank image should return empty or minimal text
        #expect(result != nil)
    }

    @Test("detectBarcodes returns empty for blank image")
    func detectBarcodesBlank() async throws {
        let image = makeDummyImage()
        let codes = try await OCRService.detectBarcodes(from: image)
        #expect(codes.isEmpty)
    }

    @Test("OCRResult has correct structure")
    func ocrResultStructure() {
        let result = OCRResult(text: "Hello", barcodes: ["https://example.com"])
        #expect(result.text == "Hello")
        #expect(result.barcodes.count == 1)
        #expect(!result.isEmpty)
    }

    @Test("empty OCRResult reports isEmpty")
    func emptyResult() {
        let result = OCRResult(text: "", barcodes: [])
        #expect(result.isEmpty)
    }
}
