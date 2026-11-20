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

    @Test("flipGlobalY is an involution")
    @MainActor func flipGlobalYInvolution() {
        let y: CGFloat = 123.5
        #expect(ScreenUtilities.flipGlobalY(ScreenUtilities.flipGlobalY(y)) == y)
    }

    @Test("flipGlobalY uses primary screen height")
    @MainActor func flipGlobalYUsesPrimaryHeight() {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        #expect(ScreenUtilities.flipGlobalY(0) == primaryHeight)
        #expect(ScreenUtilities.flipGlobalY(primaryHeight) == 0)
    }

    @Test("flipFromGlobalTopLeft is an involution")
    @MainActor func flipRectInvolution() {
        let rect = CGRect(x: 100, y: 250, width: 320, height: 180)
        let flipped = ScreenUtilities.flipFromGlobalTopLeft(rect)
        #expect(ScreenUtilities.flipFromGlobalTopLeft(flipped) == rect)
        // X・サイズは変わらない
        #expect(flipped.origin.x == rect.origin.x)
        #expect(flipped.size == rect.size)
    }

    @Test("flipFromGlobalTopLeft matches flipGlobalY for maxY")
    @MainActor func flipRectMatchesFlipY() {
        let rect = CGRect(x: 0, y: 100, width: 50, height: 30)
        let flipped = ScreenUtilities.flipFromGlobalTopLeft(rect)
        // 左下原点の maxY が左上原点の minY に対応する
        #expect(flipped.origin.y == ScreenUtilities.flipGlobalY(rect.maxY))
    }

    @Test("screen(forDisplayID:) round-trips with displayID(for:)")
    @MainActor func screenForDisplayIDRoundTrip() throws {
        let primary = try #require(NSScreen.screens.first)
        let id = ScreenUtilities.displayID(for: primary)
        let found = ScreenUtilities.screen(forDisplayID: id)
        #expect(found === primary)
    }

    @Test("scaleFactor(forDisplayID:) returns the screen's scale")
    @MainActor func scaleFactorForDisplayID() throws {
        let primary = try #require(NSScreen.screens.first)
        let id = ScreenUtilities.displayID(for: primary)
        #expect(ScreenUtilities.scaleFactor(forDisplayID: id) == primary.backingScaleFactor)
    }

    @Test("scaleFactor(forDisplayID:) falls back for unknown display")
    @MainActor func scaleFactorFallback() {
        let scale = ScreenUtilities.scaleFactor(forDisplayID: CGDirectDisplayID.max)
        #expect(scale >= 1.0)
    }
}
