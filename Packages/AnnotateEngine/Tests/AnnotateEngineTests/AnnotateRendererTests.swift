import Testing
import CoreGraphics
@testable import AnnotateEngine
import SharedModels

/// テストヘルパーで使用するエラー型
private enum TestHelperError: Error {
    case contextCreationFailed
}

@Suite("AnnotateRenderer Tests")
struct AnnotateRendererTests {
    private func makeContext(width: Int = 200, height: Int = 200) throws -> CGContext {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw TestHelperError.contextCreationFailed
        }
        return ctx
    }

    @Test("render empty items does not crash")
    func renderEmpty() throws {
        let ctx = try makeContext()
        AnnotateRenderer.render(items: [], in: ctx, size: CGSize(width: 200, height: 200))
        // No crash = pass
    }

    @Test("render each tool type does not crash")
    func renderAllTools() throws {
        let ctx = try makeContext()
        let size = CGSize(width: 200, height: 200)
        let tools: [AnnotationToolType] = [
            .arrow, .rectangle, .ellipse, .line, .text,
            .pixelate, .highlight, .counter, .pencil, .crop,
        ]
        for tool in tools {
            let item = AnnotationItem(
                toolType: tool,
                startPoint: CGPoint(x: 10, y: 10),
                endPoint: CGPoint(x: 100, y: 100),
                points: tool == .pencil
                    ? [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 100)]
                    : [],
                text: tool == .text ? "Test" : "",
                counterNumber: tool == .counter ? 1 : 0
            )
            AnnotateRenderer.render(item: item, in: ctx, size: size)
        }
        // No crash = pass
    }
}
