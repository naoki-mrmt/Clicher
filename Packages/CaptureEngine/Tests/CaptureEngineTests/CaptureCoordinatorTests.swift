import Testing
import CoreGraphics
@testable import CaptureEngine
import SharedModels

@Suite("CaptureCoordinator Tests")
struct CaptureCoordinatorTests {
    @Test("initial state is not capturing")
    @MainActor func initialState() {
        let coordinator = CaptureCoordinator()
        #expect(!coordinator.isCapturing)
        #expect(coordinator.lastResult == nil)
    }
}

@Suite("ScreenCaptureService Tests")
struct ScreenCaptureServiceTests {
    @Test("service is instantiable")
    func serviceInit() {
        let service = ScreenCaptureService()
        // ScreenCaptureService は Sendable
        _ = service
    }
}
