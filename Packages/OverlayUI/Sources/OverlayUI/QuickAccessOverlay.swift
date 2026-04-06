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

        let overlayView = QuickAccessView(
            result: result,
            onSave: { [weak self] in
                self?.onSave?(result)
                self?.dismiss()
            },
            onCopy: { [weak self] in
                ImageExporter.copyToClipboard(result.image)
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
            },
            onHoverChanged: { [weak self] hovering in
                if hovering {
                    self?.autoCloseTask?.cancel()
                    self?.autoCloseTask = nil
                } else {
                    self?.scheduleAutoClose(seconds: autoCloseSeconds)
                }
            }
        )

        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.setFrameSize(hostingView.fittingSize)

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
        panel.isMovableByWindowBackground = true

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

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                self?.panel = nil
            }
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
