import AppKit
import OSLog
import SwiftUI
import SharedModels
import Utilities

/// キャプチャ後に表示するフローティングオーバーレイ
/// サムネイル + アクションボタン（Save/Copy/Edit/Close）
@MainActor
public final class QuickAccessOverlay {
    private var panel: NSPanel?
    private var autoCloseTask: Task<Void, Never>?

    /// アプリ設定（表示位置・自動クローズ秒数）
    public var settings: AppSettings?

    /// キャプチャ完了通知時のコールバック
    public var onSave: ((CaptureResult) -> Void)?
    public var onCopy: ((CaptureResult) -> Void)?
    public var onEdit: ((CaptureResult) -> Void)?
    public var onPin: ((CaptureResult) -> Void)?

    public init() {}

    /// オーバーレイを表示
    public func show(result: CaptureResult) {
        dismiss()

        let autoCloseSeconds = TimeInterval(settings?.overlayAutoCloseSeconds ?? 5)
        let hoverState = QuickAccessHoverState()

        let overlayView = QuickAccessView(
            result: result,
            hoverState: hoverState,
            onSave: { [weak self] in
                self?.onSave?(result)
                self?.dismiss()
            },
            onCopy: { [weak self] in
                self?.onCopy?(result)
                self?.dismiss()
            },
            onEdit: { [weak self] in
                self?.onEdit?(result)
                self?.dismiss()
            },
            onPin: { [weak self] in
                self?.onPin?(result)
                self?.dismiss()
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = QuickAccessHostingView(rootView: overlayView)
        hostingView.setFrameSize(hostingView.fittingSize)
        hostingView.onHoverChanged = { [weak self] hovering in
            hoverState.isHovering = hovering
            if hovering {
                self?.autoCloseTask?.cancel()
                self?.autoCloseTask = nil
            } else if autoCloseSeconds > 0 {
                self?.scheduleAutoClose(seconds: autoCloseSeconds)
            }
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // `.draggable` で画像を Finder/Slack 等にドラッグできるようにするため、
        // パネル自体のドラッグ移動は無効化する（位置は設定で制御）
        panel.isMovableByWindowBackground = false
        panel.isMovable = false

        // 設定に応じた位置に配置
        positionPanel(panel)

        // フェードイン
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        // 自動クローズ（0 = 無効）
        if autoCloseSeconds > 0 {
            scheduleAutoClose(seconds: autoCloseSeconds)
        }

        Logger.app.info("Quick Access Overlay を表示")
    }

    /// オーバーレイを非表示
    public func dismiss() {
        autoCloseTask?.cancel()
        autoCloseTask = nil

        guard let panel else { return }
        // dismiss 中に再度 show() されると self.panel が新パネルに差し替わるため、
        // 完了時にローカル参照と一致する場合のみ nil 化する
        self.panel = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    // MARK: - Private

    private func positionPanel(_ panel: NSPanel) {
        let screen = ScreenUtilities.activeScreen
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let padding: CGFloat = 16

        let position = settings?.overlayPosition ?? .bottomRight

        let x: CGFloat
        let y: CGFloat

        switch position {
        case .topLeft:
            x = screenFrame.minX + padding
            y = screenFrame.maxY - panelSize.height - padding
        case .topRight:
            x = screenFrame.maxX - panelSize.width - padding
            y = screenFrame.maxY - panelSize.height - padding
        case .bottomLeft:
            x = screenFrame.minX + padding
            y = screenFrame.minY + padding
        case .bottomRight:
            x = screenFrame.maxX - panelSize.width - padding
            y = screenFrame.minY + padding
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func scheduleAutoClose(seconds: TimeInterval) {
        autoCloseTask?.cancel()
        autoCloseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}

/// AppKit の NSTrackingArea でホバー状態を確実に検出する NSHostingView
/// SwiftUI の `.onHover` は `.draggable` や内部ボタンと干渉してフリッカーを起こすため、
/// AppKit レベルでホスト全体を追跡対象にする
@MainActor
private final class QuickAccessHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isCurrentlyHovering = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isCurrentlyHovering else { return }
        isCurrentlyHovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard isCurrentlyHovering else { return }
        isCurrentlyHovering = false
        onHoverChanged?(false)
    }
}
