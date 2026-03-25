import Testing
import UniformTypeIdentifiers
@testable import SharedModels

@Suite("ImageFormat Tests")
struct ImageFormatTests {
    @Test("png has correct properties")
    func pngFormat() {
        let format = ImageFormat.png
        #expect(format.fileExtension == "png")
        #expect(format.utType == .png)
        #expect(format.label == "PNG")
    }

    @Test("jpeg has correct properties")
    func jpegFormat() {
        let format = ImageFormat.jpeg
        #expect(format.fileExtension == "jpeg")
        #expect(format.utType == .jpeg)
        #expect(format.label == "JPEG")
    }
}
