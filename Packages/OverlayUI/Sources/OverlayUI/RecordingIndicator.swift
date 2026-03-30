import AppKit
import SwiftUI
import OSLog
import Utilities

/// 録画中インジケーター + 停止ボタン
/// 画面上部にフローティング表示
@MainActor
public final class RecordingIndicator {
    private var panel: NSPanel?

    /// 停止ボタン押下時のコールバック
    public var onStop: (() -> Void)?

    public init() {}

    /// インジケーターを表示
    public func show() {
        dismiss()

        let view = RecordingIndicatorView(
            onStop: { [weak self] in
                self?.onStop?()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(NSSize(width: 160, height: 36))

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 160, height: 36)),
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

        // 画面上部中央に配置
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.midX - 80,
                y: screenFrame.maxY - 50
            )
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()
        self.panel = panel
        Logger.app.info("録画インジケーター表示")
    }

    /// インジケーターを非表示
    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - SwiftUI View

struct RecordingIndicatorView: View {
    let onStop: () -> Void
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            // 赤い点滅ドット
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isPulsing)
                .onAppear { isPulsing = true }

            Text("録画中")
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            // 停止ボタン
            Button {
                onStop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.red, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}
