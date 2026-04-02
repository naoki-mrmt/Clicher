import Testing
import CoreGraphics
@testable import CaptureEngine

private enum TestError: Error {
    case contextFailed, imageFailed
}

@Suite("ImageStitcher Tests")
struct ImageStitcherTests {
    private func makeImage(width: Int, height: Int) throws -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { throw TestError.contextFailed }
        guard let image = ctx.makeImage() else { throw TestError.imageFailed }
        return image
    }

    @Test("Empty array returns nil")
    func emptyReturnsNil() {
        let result = ImageStitcher.stitchVertically(images: [], overlap: 0)
        #expect(result == nil)
    }

    @Test("Single image returns itself")
    func singleImage() throws {
        let image = try makeImage(width: 100, height: 50)
        let result = ImageStitcher.stitchVertically(images: [image], overlap: 0)
        #expect(result != nil)
        #expect(result?.width == 100)
        #expect(result?.height == 50)
    }

    @Test("Two images stitch without overlap")
    func twoImagesNoOverlap() throws {
        let img1 = try makeImage(width: 100, height: 50)
        let img2 = try makeImage(width: 100, height: 60)
        let result = ImageStitcher.stitchVertically(images: [img1, img2], overlap: 0)
        #expect(result != nil)
        #expect(result?.width == 100)
        #expect(result?.height == 110)
    }

    @Test("Two images stitch with overlap")
    func twoImagesWithOverlap() throws {
        let img1 = try makeImage(width: 100, height: 50)
        let img2 = try makeImage(width: 100, height: 50)
        let result = ImageStitcher.stitchVertically(images: [img1, img2], overlap: 10)
        #expect(result != nil)
        #expect(result?.width == 100)
        #expect(result?.height == 90) // 50 + 50 - 10
    }

    @Test("Overlap is clamped to half of smallest frame")
    func overlapClamped() throws {
        let img1 = try makeImage(width: 100, height: 20)
        let img2 = try makeImage(width: 100, height: 30)
        // overlap=50 should be clamped to 10 (half of 20)
        let result = ImageStitcher.stitchVertically(images: [img1, img2], overlap: 50)
        #expect(result != nil)
        #expect(result?.height == 40) // 20 + 30 - 10
    }
}
