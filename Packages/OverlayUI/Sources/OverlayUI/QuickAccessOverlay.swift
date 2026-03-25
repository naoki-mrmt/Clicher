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

    /// キャプチャ完了通知時のコールバック
    public var onSave: ((CaptureResult) -> Void)?
    public var onCopy: ((CaptureResult) -> Void)?
    public var onEdit: ((CaptureResult) -> Void)?

    public init() {}

    /// オーバーレイを表示
    public func show(result: CaptureResult) {
        dismiss()

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
            onClose: { [weak self] in
                self?.dismiss()
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

        // 画面右下に配置
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

        // 5秒後に自動クローズ
        scheduleAutoClose(seconds: 5)

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
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let padding: CGFloat = 16

        let origin = NSPoint(
            x: screenFrame.maxX - panelSize.width - padding,
            y: screenFrame.minY + padding
        )
        panel.setFrameOrigin(origin)
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
