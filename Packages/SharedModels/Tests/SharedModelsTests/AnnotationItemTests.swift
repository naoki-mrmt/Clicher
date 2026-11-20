import Testing
import CoreGraphics
@testable import SharedModels

@Suite("AnnotationItem Tests")
struct AnnotationItemTests {
    @Test("boundingRect for standard tools uses start/end points")
    func boundingRectStandard() {
        let item = AnnotationItem(
            toolType: .rectangle,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 50, y: 80)
        )
        let rect = item.boundingRect
        #expect(rect.origin.x == 10)
        #expect(rect.origin.y == 20)
        #expect(rect.width == 40)
        #expect(rect.height == 60)
    }

    @Test("boundingRect for pencil uses points array")
    func boundingRectPencil() {
        let item = AnnotationItem(
            toolType: .pencil,
            points: [
                CGPoint(x: 5, y: 10),
                CGPoint(x: 25, y: 30),
                CGPoint(x: 15, y: 20),
            ]
        )
        let rect = item.boundingRect
        let padding = item.style.lineWidth / 2
        #expect(rect.origin.x == 5 - padding)
        #expect(rect.origin.y == 10 - padding)
        #expect(rect.width == 20 + item.style.lineWidth)
        #expect(rect.height == 20 + item.style.lineWidth)
    }

    @Test("boundingRect for pencil with no points returns zero")
    func boundingRectPencilEmpty() {
        let item = AnnotationItem(toolType: .pencil)
        #expect(item.boundingRect == .zero)
    }

    @Test("copy preserves id and values")
    func copyPreservesIdentity() {
        let item = AnnotationItem(
            toolType: .rectangle,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 50, y: 80),
            text: "hello",
            counterNumber: 3
        )
        let copied = item.copy()
        #expect(copied !== item)
        #expect(copied.id == item.id)
        #expect(copied.toolType == item.toolType)
        #expect(copied.startPoint == item.startPoint)
        #expect(copied.endPoint == item.endPoint)
        #expect(copied.text == item.text)
        #expect(copied.counterNumber == item.counterNumber)
    }

    @Test("copy is independent of original")
    func copyIsDeep() {
        let item = AnnotationItem(toolType: .pencil, points: [CGPoint(x: 1, y: 1)])
        let copied = item.copy()
        copied.points.append(CGPoint(x: 2, y: 2))
        #expect(item.points.count == 1)
        #expect(copied.points.count == 2)
    }

    @Test("default style values")
    func defaultStyle() {
        let style = AnnotationStyle()
        #expect(style.lineWidth == 3.0)
        #expect(style.fontSize == 24.0)
        #expect(style.fontName == ".AppleSystemUIFont")
        #expect(style.isFilled == false)
        #expect(style.cornerRadius == 0)
    }
}
