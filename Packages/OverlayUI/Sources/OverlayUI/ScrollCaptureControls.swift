import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities

/// スクロールキャプチャ操作パネル
@MainActor
public final class ScrollCaptureControls {
    private var panel: NSPanel?

    public var onCaptureFrame: (() -> Void)?
    public var onFinish: (() -> Void)?
    public var onCancel: (() -> Void)?

    /// 現在のフレーム数（外部から更新）
    public var frameCount: Int = 0

    public init() {}

    /// コントロールパネルを表示
    public func show() {
        dismiss()

        let view = ScrollCaptureControlsView(
            frameCount: { self.frameCount },
            onCaptureFrame: { [weak self] in self?.onCaptureFrame?() },
            onFinish: { [weak self] in
                self?.onFinish?()
                self?.dismiss()
            },
            onCancel: { [weak self] in
                self?.onCancel?()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(NSSize(width: 280, height: 48))

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 280, height: 48)),
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

        // 画面下部中央
        let screenFrame = ScreenUtilities.activeVisibleFrame
        let origin = NSPoint(
            x: screenFrame.midX - 140,
            y: screenFrame.minY + 60
        )
        panel.setFrameOrigin(origin)

        panel.orderFrontRegardless()
        self.panel = panel
        Logger.app.info("スクロールキャプチャコントロール表示")
    }

    /// パネルを非表示
    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct ScrollCaptureControlsView: View {
    let frameCount: () -> Int
    let onCaptureFrame: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // フレーム数
            Text(L10n.frameCount(frameCount()))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 80)

            // 次のフレームをキャプチャ
            Button {
                onCaptureFrame()
            } label: {
                Label(L10n.captureFrame, systemImage: "camera")
                    .font(.caption)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)

            // 完了
            Button {
                onFinish()
            } label: {
                Label(L10n.done, systemImage: "checkmark")
                    .font(.caption)
            }
            .controlSize(.small)

            // キャンセル
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .controlSize(.small)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}
