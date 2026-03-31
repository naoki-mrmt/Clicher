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
        NSApp.activate(ignoringOtherApps: true)
        orderFrontRegardless()
        makeKey()
        NSCursor.crosshair.set()
        invalidateCursorRects(for: contentView!)
    }

    private func finishSelection(rect: CGRect?) {
        NSCursor.arrow.set()
        orderOut(nil)
        completionHandler?(rect)
        completionHandler = nil
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape でキャンセル
        if event.keyCode == 53 {
            finishSelection(rect: nil)
            return
        }
        // Enter / Return で選択確定
        if event.keyCode == 36 || event.keyCode == 76 {
            if let view = selectionView {
                view.confirmSelection()
            }
        }
    }
}

// MARK: - AreaSelectionView

/// マウスドラッグで選択範囲を描画するビュー
private final class AreaSelectionView: NSView {
    private enum Phase { case idle, drawing, adjusting }

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var completionHandler: ((CGRect?) -> Void)?
    private var phase: Phase = .idle
    private var adjustDragStart: NSPoint?

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
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch phase {
        case .idle:
            startPoint = point
            currentPoint = point
            phase = .drawing

        case .adjusting:
            // ダブルクリック → 確定
            if event.clickCount == 2, let rect = selectionRect, rect.contains(point) {
                confirmSelection()
                return
            }
            // 選択範囲内ドラッグ → 移動
            if let rect = selectionRect, rect.contains(point) {
                adjustDragStart = point
            } else {
                // 選択範囲外 → 新規描画
                startPoint = point
                currentPoint = point
                phase = .drawing
            }

        case .drawing:
            break
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch phase {
        case .drawing:
            currentPoint = point

        case .adjusting:
            // 選択範囲を移動
            if let dragStart = adjustDragStart, let start = startPoint, let current = currentPoint {
                let dx = point.x - dragStart.x
                let dy = point.y - dragStart.y
                startPoint = NSPoint(x: start.x + dx, y: start.y + dy)
                currentPoint = NSPoint(x: current.x + dx, y: current.y + dy)
                adjustDragStart = point
            }

        case .idle:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch phase {
        case .drawing:
            currentPoint = point
            guard let rect = selectionRect, rect.width > 2, rect.height > 2 else {
                // 小さすぎる → リセット
                startPoint = nil
                currentPoint = nil
                phase = .idle
                needsDisplay = true
                return
            }
            // 描画完了 → 調整モードへ
            phase = .adjusting

        case .adjusting:
            adjustDragStart = nil

        case .idle:
            break
        }
        needsDisplay = true
    }

    /// 選択を確定して完了
    fileprivate func confirmSelection() {
        guard let rect = selectionRect, let windowFrame = window?.frame else {
            completionHandler?(nil)
            return
        }
        let screenRect = CGRect(
            x: windowFrame.origin.x + rect.origin.x,
            y: windowFrame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )
        completionHandler?(screenRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        // 背景を暗くする（Lark 風）
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()

        guard let rect = selectionRect else { return }

        // 選択範囲を完全にクリア（明るく見える）
        NSColor.clear.setFill()
        rect.fill(using: .copy)

        // 選択範囲の枠線（水色、2px）
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2.0
        path.stroke()

        // 四隅にハンドル
        let handleSize: CGFloat = 6
        NSColor.white.setFill()
        for point in [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ] {
            let handleRect = NSRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            NSBezierPath(ovalIn: handleRect).fill()
        }

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
