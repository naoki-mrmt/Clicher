import AppKit
import OSLog
import ScreenCaptureKit
import Utilities

/// エリア選択の結果
public enum AreaSelectionResult {
    /// ドラッグによるエリア選択
    case area(CGRect)
    /// クリックによるウィンドウ選択（クリック位置、macOS スクリーン座標）
    case windowClick(CGPoint)
}

/// エリア選択オーバーレイ
/// 全画面透明ウィンドウでマウスドラッグによる範囲選択を行う
/// クリック（ドラッグなし）の場合はウィンドウ選択として扱う
public final class AreaSelectionOverlay {
    /// ウィンドウの強参照（ARC による早期解放を防ぐ）
    @MainActor private static var activeWindow: AreaSelectionWindow?

    /// エリア選択を開始し、ユーザーが範囲を選択するまで待機
    /// キャンセル（Esc）の場合は nil を返す
    public static func selectArea() async -> CGRect? {
        let result = await select()
        switch result {
        case .area(let rect):
            return rect
        case .windowClick, .none:
            return nil
        }
    }

    /// エリア選択またはウィンドウクリックを開始
    /// ドラッグ → .area、クリック → .windowClick、ESC → nil
    public static func select() async -> AreaSelectionResult? {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                var resumed = false
                let overlay = AreaSelectionWindow { result in
                    guard !resumed else { return }
                    resumed = true
                    activeWindow = nil
                    nonisolated(unsafe) let safeResult = result
                    continuation.resume(returning: safeResult)
                }
                activeWindow = overlay
                overlay.show()
            }
        }
    }
}

// MARK: - AreaSelectionWindow

/// 透明なフルスクリーンウィンドウでエリア選択UIを提供
private final class AreaSelectionWindow: NSWindow {
    private var selectionView: AreaSelectionView?
    private var completionHandler: ((AreaSelectionResult?) -> Void)?

    init(completion: @escaping (AreaSelectionResult?) -> Void) {
        self.completionHandler = completion

        let screen = ScreenUtilities.activeScreen

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

        let view = AreaSelectionView { [weak self] result in
            self?.finishSelection(result)
        }
        self.selectionView = view
        contentView = view
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        orderFrontRegardless()
        makeKey()
        NSCursor.crosshair.push()
        if let view = contentView {
            invalidateCursorRects(for: view)
        }
    }

    private func finishSelection(_ result: AreaSelectionResult?) {
        // カーソル矩形を解除してからウィンドウを消す（crosshair 残留防止）
        if let view = contentView {
            view.discardCursorRects()
        }
        orderOut(nil)
        NSCursor.pop()
        NSCursor.arrow.set()
        completionHandler?(result)
        completionHandler = nil
    }

    override var canBecomeKey: Bool { true }

    // MARK: - Key Codes
    private static let kEscape: UInt16 = 53
    private static let kReturn: UInt16 = 36
    private static let kNumpadEnter: UInt16 = 76
    private static let kLeftArrow: UInt16 = 123
    private static let kRightArrow: UInt16 = 124
    private static let kDownArrow: UInt16 = 125
    private static let kUpArrow: UInt16 = 126

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.kEscape {
            finishSelection(nil)
            return
        }
        if event.keyCode == Self.kReturn || event.keyCode == Self.kNumpadEnter {
            if let view = selectionView {
                view.confirmSelection()
            }
            return
        }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case Self.kLeftArrow:  selectionView?.nudgeSelection(dx: -step, dy: 0)
        case Self.kRightArrow: selectionView?.nudgeSelection(dx: step, dy: 0)
        case Self.kDownArrow:  selectionView?.nudgeSelection(dx: 0, dy: step)
        case Self.kUpArrow:    selectionView?.nudgeSelection(dx: 0, dy: -step)
        default: break
        }
    }
}

// MARK: - AreaSelectionView

/// マウスドラッグで選択範囲を描画するビュー
private final class AreaSelectionView: NSView {
    private enum Phase { case idle, drawing, adjusting }

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var completionHandler: ((AreaSelectionResult?) -> Void)?
    private var phase: Phase = .idle
    private var adjustDragStart: NSPoint?

    /// 利用可能なウィンドウ一覧（ホバーハイライト用、非同期取得）
    private var availableWindows: [SCWindow] = []
    /// ホバー中のウィンドウ矩形（ビュー座標、idle 時のみ表示）
    private var hoveredWindowRect: NSRect?

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

    init(completion: @escaping (AreaSelectionResult?) -> Void) {
        self.completionHandler = completion
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))

        // ウィンドウ一覧を非同期で取得（ホバーハイライト用）
        Task { @MainActor [weak self] in
            guard let self else { return }
            let bundleID = Bundle.main.bundleIdentifier
            if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) {
                self.availableWindows = content.windows.filter { window in
                    window.isOnScreen
                        && window.frame.width > 10
                        && window.frame.height > 10
                        && window.owningApplication?.bundleIdentifier != bundleID
                }
            }
        }
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
        // idle 時のみウィンドウホバーハイライトを更新
        if phase == .idle {
            let viewPoint = convert(event.locationInWindow, from: nil)
            let newRect = windowRectAtViewPoint(viewPoint)
            if newRect != hoveredWindowRect {
                hoveredWindowRect = newRect
                needsDisplay = true
            }
        }
    }

    /// ビュー座標のポイントにあるウィンドウの矩形（ビュー座標、左下原点）を返す
    private func windowRectAtViewPoint(_ point: NSPoint) -> NSRect? {
        guard let win = window else { return nil }
        // ビュー座標 → グローバル NSScreen 座標
        let screenPoint = win.convertPoint(toScreen: point)

        // NSScreen 座標（左下原点・グローバル）→ SCK 座標（左上原点・グローバル）に変換
        // メインスクリーンの高さを基準にする
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let sckPoint = CGPoint(x: screenPoint.x, y: mainHeight - screenPoint.y)

        guard let scWindow = availableWindows.first(where: { $0.frame.contains(sckPoint) }) else {
            return nil
        }

        // SCK frame（左上原点）→ NSScreen frame（左下原点）→ ビュー座標
        let scFrame = scWindow.frame
        let macScreenRect = NSRect(
            x: scFrame.origin.x,
            y: mainHeight - scFrame.origin.y - scFrame.height,
            width: scFrame.width,
            height: scFrame.height
        )
        let viewRect = win.convertFromScreen(macScreenRect)
        return viewRect
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // ドラッグ開始時はホバーハイライトを消す
        hoveredWindowRect = nil

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
            // Shift で正方形に制約
            if event.modifierFlags.contains(.shift), let start = startPoint {
                let dx = point.x - start.x
                let dy = point.y - start.y
                let side = max(abs(dx), abs(dy))
                currentPoint = NSPoint(
                    x: start.x + (dx >= 0 ? side : -side),
                    y: start.y + (dy >= 0 ? side : -side)
                )
            } else {
                currentPoint = point
            }

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
            guard let rect = selectionRect, rect.width >= 4, rect.height >= 4 else {
                // 小さすぎるドラッグ → ウィンドウクリックとして扱う
                let clickPoint = convert(point, to: nil)
                let screenPoint = window?.convertPoint(toScreen: clickPoint) ?? point
                startPoint = nil
                currentPoint = nil
                phase = .idle
                completionHandler?(.windowClick(screenPoint))
                return
            }
            // 描画完了 → 即確定（Lark 風）
            confirmSelection()

        case .adjusting:
            adjustDragStart = nil

        case .idle:
            break
        }
        needsDisplay = true
    }

    /// 矢印キーで選択範囲を移動
    fileprivate func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard startPoint != nil, currentPoint != nil else { return }
        startPoint?.x += dx
        startPoint?.y += dy
        currentPoint?.x += dx
        currentPoint?.y += dy
        needsDisplay = true
    }

    /// 選択を確定して完了
    fileprivate func confirmSelection() {
        guard let rect = selectionRect, let win = window else {
            completionHandler?(nil)
            return
        }
        // NSView 座標 → NSScreen 座標に正確に変換
        let screenRect = win.convertToScreen(rect)
        completionHandler?(.area(screenRect))
    }

    override func draw(_ dirtyRect: NSRect) {
        // 背景を暗くする（Lark 風）
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()

        // ホバー中のウィンドウをハイライト（idle 時のみ）
        if phase == .idle, let hoverRect = hoveredWindowRect {
            // ウィンドウ範囲を明るく
            NSColor.clear.setFill()
            hoverRect.fill(using: .copy)
            NSColor.systemBlue.withAlphaComponent(0.1).setFill()
            hoverRect.fill()
            // 青枠
            NSColor.systemBlue.withAlphaComponent(0.7).setStroke()
            let hoverPath = NSBezierPath(rect: hoverRect.insetBy(dx: 1, dy: 1))
            hoverPath.lineWidth = 2.0
            hoverPath.stroke()
        }

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
        let labelWidth = textSize.width + 8
        let labelHeight = textSize.height + 4

        // デフォルトは選択範囲の下に配置
        var labelX = rect.midX - labelWidth / 2
        var labelY = rect.minY - labelHeight - 8

        // 画面端で見切れる場合はクランプ
        let viewBounds = bounds
        if labelY < viewBounds.minY + 4 {
            // 下に余白がなければ上に配置
            labelY = rect.maxY + 8
        }
        labelX = max(viewBounds.minX + 4, min(labelX, viewBounds.maxX - labelWidth - 4))

        let labelRect = NSRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)

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
