import Testing
import CoreGraphics
@testable import CaptureEngine

@Suite("ScrollCapture Tests")
struct ScrollCaptureTests {
    private func makeColorImage(width: Int = 200, height: Int = 100, red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )!
        ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    @Test("ImageStitcher can stitch two images vertically")
    func stitchTwoImages() {
        let img1 = makeColorImage(red: 1, green: 0, blue: 0)
        let img2 = makeColorImage(red: 0, green: 0, blue: 1)
        let result = ImageStitcher.stitchVertically(images: [img1, img2], overlap: 0)
        #expect(result != nil)
        if let result {
            #expect(result.width == 200)
            #expect(result.height == 200) // 100 + 100
        }
    }

    @Test("ImageStitcher with overlap reduces height")
    func stitchWithOverlap() {
        let img1 = makeColorImage(red: 1, green: 0, blue: 0)
        let img2 = makeColorImage(red: 0, green: 0, blue: 1)
        let result = ImageStitcher.stitchVertically(images: [img1, img2], overlap: 20)
        #expect(result != nil)
        if let result {
            #expect(result.width == 200)
            #expect(result.height == 180) // 100 + 100 - 20
        }
    }

    @Test("ImageStitcher with single image returns that image")
    func stitchSingleImage() {
        let img = makeColorImage(red: 1, green: 0, blue: 0)
        let result = ImageStitcher.stitchVertically(images: [img], overlap: 0)
        #expect(result != nil)
        if let result {
            #expect(result.width == 200)
            #expect(result.height == 100)
        }
    }

    @Test("ImageStitcher with empty array returns nil")
    func stitchEmpty() {
        let result = ImageStitcher.stitchVertically(images: [], overlap: 0)
        #expect(result == nil)
    }

    @Test("ScrollCaptureSession initial state")
    @MainActor func sessionInit() {
        let session = ScrollCaptureSession()
        #expect(session.frames.isEmpty)
        #expect(!session.isCapturing)
    }
}
