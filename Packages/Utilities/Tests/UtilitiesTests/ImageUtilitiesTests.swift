import Testing
import CoreGraphics
@testable import Utilities

/// テストヘルパーで使用するエラー型
private enum TestHelperError: Error {
    case contextCreationFailed
    case imageCreationFailed
}

@Suite("ImageUtilities Tests")
struct ImageUtilitiesTests {
    private func makeImage(width: Int = 100, height: Int = 50) throws -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
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

    @Test("combine horizontal")
    func combineHorizontal() throws {
        let img1 = try makeImage(width: 100, height: 50)
        let img2 = try makeImage(width: 80, height: 50)
        let result = ImageUtilities.combine(images: [img1, img2], direction: .horizontal)
        #expect(result != nil)
        #expect(result?.width == 180)
        #expect(result?.height == 50)
    }

    @Test("combine horizontal with spacing")
    func combineHorizontalSpacing() throws {
        let img1 = try makeImage(width: 100, height: 50)
        let img2 = try makeImage(width: 100, height: 50)
        let result = ImageUtilities.combine(images: [img1, img2], direction: .horizontal, spacing: 10)
        #expect(result?.width == 210)
    }

    @Test("combine vertical")
    func combineVertical() throws {
        let img1 = try makeImage(width: 100, height: 50)
        let img2 = try makeImage(width: 100, height: 30)
        let result = ImageUtilities.combine(images: [img1, img2], direction: .vertical)
        #expect(result != nil)
        #expect(result?.width == 100)
        #expect(result?.height == 80)
    }

    @Test("rotate right swaps dimensions")
    func rotateRight() throws {
        let img = try makeImage(width: 100, height: 50)
        let result = ImageUtilities.transform(img, orientation: .rotateRight)
        #expect(result != nil)
        #expect(result?.width == 50)
        #expect(result?.height == 100)
    }

    @Test("rotate left swaps dimensions")
    func rotateLeft() throws {
        let img = try makeImage(width: 100, height: 50)
        let result = ImageUtilities.transform(img, orientation: .rotateLeft)
        #expect(result?.width == 50)
        #expect(result?.height == 100)
    }

    @Test("flip preserves dimensions")
    func flipPreservesDimensions() throws {
        let img = try makeImage(width: 100, height: 50)
        let hFlip = ImageUtilities.transform(img, orientation: .flipHorizontal)
        let vFlip = ImageUtilities.transform(img, orientation: .flipVertical)
        #expect(hFlip?.width == 100)
        #expect(hFlip?.height == 50)
        #expect(vFlip?.width == 100)
        #expect(vFlip?.height == 50)
    }

    @Test("rotate 180 preserves dimensions")
    func rotate180() throws {
        let img = try makeImage(width: 100, height: 50)
        let result = ImageUtilities.transform(img, orientation: .rotate180)
        #expect(result?.width == 100)
        #expect(result?.height == 50)
    }

    @Test("combine empty returns nil")
    func combineEmpty() {
        let result = ImageUtilities.combine(images: [], direction: .horizontal)
        #expect(result == nil)
    }

    @Test("combine single returns same")
    func combineSingle() throws {
        let img = try makeImage()
        let result = ImageUtilities.combine(images: [img], direction: .vertical)
        #expect(result?.width == 100)
    }
}
