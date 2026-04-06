import Testing
import AppKit
@testable import Utilities

@Suite("ScreenUtilities Tests")
struct ScreenUtilitiesTests {
    @Test("activeScreen returns a valid screen")
    @MainActor func activeScreenReturnsValid() {
        let screen = ScreenUtilities.activeScreen
        #expect(screen.frame.width > 0)
        #expect(screen.frame.height > 0)
    }

    @Test("activeScreenFrame has positive dimensions")
    @MainActor func activeScreenFramePositive() {
        let frame = ScreenUtilities.activeScreenFrame
        #expect(frame.width > 0)
        #expect(frame.height > 0)
    }

    @Test("activeVisibleFrame is within activeScreenFrame")
    @MainActor func visibleFrameWithinScreen() {
        let screen = ScreenUtilities.activeScreenFrame
        let visible = ScreenUtilities.activeVisibleFrame
        #expect(visible.width <= screen.width)
        #expect(visible.height <= screen.height)
    }

    @Test("activeScaleFactor is at least 1.0")
    @MainActor func scaleFactorAtLeast1() {
        let scale = ScreenUtilities.activeScaleFactor
        #expect(scale >= 1.0)
    }

    @Test("activeScreen is one of NSScreen.screens")
    @MainActor func activeScreenInScreensList() {
        let active = ScreenUtilities.activeScreen
        let allScreens = NSScreen.screens
        let found = allScreens.contains { $0 === active }
        #expect(found)
    }

    @Test("activeScreenFrame matches activeScreen.frame")
    @MainActor func frameConsistency() {
        let screen = ScreenUtilities.activeScreen
        let frame = ScreenUtilities.activeScreenFrame
        #expect(frame == screen.frame)
    }

    @Test("activeVisibleFrame matches activeScreen.visibleFrame")
    @MainActor func visibleFrameConsistency() {
        let screen = ScreenUtilities.activeScreen
        let visible = ScreenUtilities.activeVisibleFrame
        #expect(visible == screen.visibleFrame)
    }

    @Test("activeScaleFactor matches activeScreen.backingScaleFactor")
    @MainActor func scaleFactorConsistency() {
        let screen = ScreenUtilities.activeScreen
        let scale = ScreenUtilities.activeScaleFactor
        #expect(scale == screen.backingScaleFactor)
    }
}
