import AppKit
import SwiftUI
import OSLog
import Utilities

/// トースト通知の種類
public enum ToastStyle {
    case success
    case error
    case info

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .success: .green
        case .error: .red
        case .info: .blue
        }
    }
}

/// 一時的なトースト通知を表示するオーバーレイ
@MainActor
public final class ToastOverlay {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    public init() {}

    /// トーストを表示
    public func show(_ message: String, style: ToastStyle = .info, duration: TimeInterval = 3) {
        dismiss()

        let view = ToastView(message: message, style: style)
        let hostingView = NSHostingView(rootView: view)
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

        // 画面上部中央に配置
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.midX - hostingView.fittingSize.width / 2,
                y: screenFrame.maxY - hostingView.fittingSize.height - 60
            )
            panel.setFrameOrigin(origin)
        }

        // フェードイン
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        // 自動で消える
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    /// トーストを非表示
    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        guard let panel else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                self?.panel = nil
            }
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let style: ToastStyle

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.icon)
                .foregroundStyle(style.iconColor)
                .font(.body)

            Text(message)
                .font(.callout)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}
