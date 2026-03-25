import AppKit
import OSLog
import Utilities

/// エリア選択オーバーレイ
/// 全画面透明ウィンドウでマウスドラッグによる範囲選択を行う
public final class AreaSelectionOverlay {
    /// エリア選択を開始し、ユーザーが範囲を選択するまで待機
    /// キャンセル（Esc）の場合は nil を返す
    public static func selectArea() async -> CGRect? {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let overlay = AreaSelectionWindow { rect in
                    continuation.resume(returning: rect)
                }
                overlay.show()
            }
        }
    }
}

// MARK: - AreaSelectionWindow

/// 透明なフルスクリーンウィンドウでエリア選択UIを提供
private final class AreaSelectionWindow: NSWindow {
    private var selectionView: AreaSelectionView?
    private var completionHandler: ((CGRect?) -> Void)?

    init(completion: @escaping (CGRect?) -> Void) {
        self.completionHandler = completion

        guard let screen = NSScreen.main else {
            completion(nil)
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            return
        }

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.01)
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        let view = AreaSelectionView { [weak self] rect in
            self?.finishSelection(rect: rect)
        }
        self.selectionView = view
        contentView = view
    }

    func show() {
        orderFrontRegardless()
        makeKey()
    }

    private func finishSelection(rect: CGRect?) {
        orderOut(nil)
        completionHandler?(rect)
        completionHandler = nil
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape でキャンセル
        if event.keyCode == 53 {
            finishSelection(rect: nil)
        }
    }
}

// MARK: - AreaSelectionView

/// マウスドラッグで選択範囲を描画するビュー
private final class AreaSelectionView: NSView {
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var completionHandler: ((CGRect?) -> Void)?

    /// 選択中の矩形
    private var selectionRect: NSRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    init(completion: @escaping (CGRect?) -> Void) {
        self.completionHandler = completion
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)

        guard let rect = selectionRect, rect.width > 2, rect.height > 2 else {
            // 小さすぎる選択はキャンセル扱い
            completionHandler?(nil)
            return
        }

        // NSView 座標 → スクリーン座標に変換
        guard let windowFrame = window?.frame else {
            completionHandler?(nil)
            return
        }

        let screenRect = CGRect(
            x: windowFrame.origin.x + rect.origin.x,
            y: windowFrame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        // macOS の座標系は左下原点 → ScreenCaptureKit は左上原点
        if let screenHeight = NSScreen.main?.frame.height {
            let flippedRect = CGRect(
                x: screenRect.origin.x,
                y: screenHeight - screenRect.origin.y - screenRect.height,
                width: screenRect.width,
                height: screenRect.height
            )
            completionHandler?(flippedRect)
        } else {
            completionHandler?(screenRect)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // 背景を薄暗く
        NSColor.black.withAlphaComponent(0.2).setFill()
        dirtyRect.fill()

        guard let rect = selectionRect else { return }

        // 選択範囲を透明にクリア
        NSColor.clear.setFill()
        rect.fill(using: .copy)

        // 選択範囲の枠線
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1.0
        path.stroke()

        // サイズ表示
        drawSizeLabel(for: rect)
    }

    /// 選択範囲のサイズをラベル表示
    private func drawSizeLabel(for rect: NSRect) {
        let scaleFactor = window?.screen?.backingScaleFactor ?? 2.0
        let pixelWidth = Int(rect.width * scaleFactor)
        let pixelHeight = Int(rect.height * scaleFactor)
        let sizeText = "\(pixelWidth) × \(pixelHeight)" as NSString

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
        ]

        let textSize = sizeText.size(withAttributes: attributes)
        let labelRect = NSRect(
            x: rect.midX - textSize.width / 2 - 4,
            y: rect.minY - textSize.height - 8,
            width: textSize.width + 8,
            height: textSize.height + 4
        )

        // 背景
        NSColor.black.withAlphaComponent(0.7).setFill()
        let bgPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        bgPath.fill()

        // テキスト
        sizeText.draw(
            at: NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2),
            withAttributes: attributes
        )
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
