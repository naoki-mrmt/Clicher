import AppKit
import ScreenCaptureKit
import OSLog
import Utilities

/// ウィンドウ選択オーバーレイ
/// マウスホバーでウィンドウをハイライト、クリックで選択
public final class WindowSelectionOverlay {
    /// ウィンドウの強参照（ARC による早期解放を防ぐ）
    @MainActor private static var activeWindow: WindowSelectionWindow?

    /// ウィンドウ選択を開始し、ユーザーが選択するまで待機
    /// キャンセル（Esc）の場合は nil を返す
    @MainActor
    public static func selectWindow(from windows: [SCWindow]) async -> SCWindow? {
        // 自分自身のアプリと無効なウィンドウを除外
        let bundleID = Bundle.main.bundleIdentifier
        let validWindows = windows.filter { window in
            window.isOnScreen
                && window.frame.width > 10
                && window.frame.height > 10
                && window.owningApplication?.bundleIdentifier != bundleID
        }

        guard !validWindows.isEmpty else {
            Logger.capture.warning("選択可能なウィンドウがありません")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let overlay = WindowSelectionWindow(windows: validWindows) { window in
                activeWindow = nil
                nonisolated(unsafe) let selected = window
                continuation.resume(returning: selected)
            }
            activeWindow = overlay
            overlay.show()
        }
    }
}

// MARK: - WindowSelectionWindow

/// ウィンドウ選択用の透明フルスクリーンウィンドウ
private final class WindowSelectionWindow: NSWindow {
    private let validWindows: [SCWindow]
    private var completionHandler: ((SCWindow?) -> Void)?
    private var highlightWindow: NSWindow?

    init(windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        self.validWindows = windows
        self.completionHandler = completion

        let screenFrame = ScreenUtilities.activeScreenFrame

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.15)
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        contentView = WindowSelectionView()
    }

    func show() {
        orderFrontRegardless()
        makeKey()
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            finishSelection(nil)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let screenPoint = convertToScreen(event.locationInWindow)
        updateHighlight(at: screenPoint)
    }

    override func mouseUp(with event: NSEvent) {
        let screenPoint = convertToScreen(event.locationInWindow)
        if let window = windowAtPoint(screenPoint) {
            finishSelection(window)
        }
    }

    /// 変換ヘルパー（NSPoint → screen座標）
    private func convertToScreen(_ point: NSPoint) -> NSPoint {
        convertPoint(toScreen: point)
    }

    /// 指定座標にあるウィンドウを検索
    private func windowAtPoint(_ point: NSPoint) -> SCWindow? {
        let screenHeight = ScreenUtilities.activeScreenFrame.height

        // macOS座標系(左下原点) → ScreenCaptureKit座標系(左上原点)
        let flippedY = screenHeight - point.y

        return validWindows.first { window in
            let frame = window.frame
            return frame.contains(CGPoint(x: point.x, y: flippedY))
        }
    }

    /// ホバー中のウィンドウをハイライト
    private func updateHighlight(at point: NSPoint) {
        let screenHeight = ScreenUtilities.activeScreenFrame.height

        if let window = windowAtPoint(point) {
            let frame = window.frame
            // ScreenCaptureKit座標 → macOS座標に変換
            let macFrame = NSRect(
                x: frame.origin.x,
                y: screenHeight - frame.origin.y - frame.height,
                width: frame.width,
                height: frame.height
            )
            showHighlight(frame: macFrame)
        } else {
            hideHighlight()
        }
    }

    private func showHighlight(frame: NSRect) {
        if highlightWindow == nil {
            let hw = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            hw.level = .screenSaver + 1
            hw.isOpaque = false
            hw.backgroundColor = .clear
            hw.hasShadow = false
            hw.ignoresMouseEvents = true

            let view = HighlightView(frame: frame)
            hw.contentView = view
            highlightWindow = hw
        }

        highlightWindow?.setFrame(frame, display: true)
        highlightWindow?.orderFrontRegardless()
    }

    private func hideHighlight() {
        highlightWindow?.orderOut(nil)
        highlightWindow?.close()
        highlightWindow = nil
    }

    private func finishSelection(_ window: SCWindow?) {
        hideHighlight()
        orderOut(nil)
        completionHandler?(window)
        completionHandler = nil
    }
}

// MARK: - Views

private final class WindowSelectionView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// ウィンドウハイライト枠
private final class HighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let borderColor = NSColor.systemBlue.withAlphaComponent(0.6)
        let fillColor = NSColor.systemBlue.withAlphaComponent(0.1)

        fillColor.setFill()
        bounds.fill()

        borderColor.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        path.lineWidth = 3
        path.stroke()
    }
}
