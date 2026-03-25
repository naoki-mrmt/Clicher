import Testing
import CoreGraphics
@testable import AnnotateEngine

@Suite("BackgroundTool Tests")
struct BackgroundToolTests {
    private func makeDummyImage(width: Int = 200, height: Int = 100) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    @Test("solid color background renders correctly")
    func solidColor() {
        let image = makeDummyImage()
        let config = BackgroundConfig(
            style: .solidColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)),
            padding: 20
        )
        let result = BackgroundTool.apply(to: image, config: config)
        #expect(result != nil)
        if let result {
            #expect(result.width == 200 + 40) // image + padding * 2
            #expect(result.height == 100 + 40)
        }
    }

    @Test("gradient background renders correctly")
    func gradient() {
        let image = makeDummyImage()
        let config = BackgroundConfig(
            style: .gradient(
                startColor: CGColor(red: 1, green: 0, blue: 0.5, alpha: 1),
                endColor: CGColor(red: 0, green: 0.5, blue: 1, alpha: 1),
                angle: 45
            ),
            padding: 30
        )
        let result = BackgroundTool.apply(to: image, config: config)
        #expect(result != nil)
    }

    @Test("zero padding preserves original size")
    func zeroPadding() {
        let image = makeDummyImage()
        let config = BackgroundConfig(style: .solidColor(.black), padding: 0)
        let result = BackgroundTool.apply(to: image, config: config)
        #expect(result != nil)
        if let result {
            #expect(result.width == 200)
            #expect(result.height == 100)
        }
    }

    @Test("SNS presets have valid dimensions")
    func snsPresets() {
        for preset in SNSSizePreset.allCases {
            #expect(preset.size.width > 0)
            #expect(preset.size.height > 0)
            #expect(!preset.label.isEmpty)
        }
    }

    @Test("resize to SNS preset works")
    func resizeToPreset() {
        let image = makeDummyImage()
        let config = BackgroundConfig(
            style: .solidColor(.white),
            padding: 20,
            targetSize: SNSSizePreset.twitterPost.size
        )
        let result = BackgroundTool.apply(to: image, config: config)
        #expect(result != nil)
        if let result {
            #expect(result.width == Int(SNSSizePreset.twitterPost.size.width))
            #expect(result.height == Int(SNSSizePreset.twitterPost.size.height))
        }
    }
}
