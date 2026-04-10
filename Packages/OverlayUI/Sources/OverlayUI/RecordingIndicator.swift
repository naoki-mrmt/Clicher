import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities

/// 録画中インジケーター + 停止ボタン + 録画範囲ハイライト
/// 画面上部にフローティング表示し、録画範囲外を暗転させる
@MainActor
public final class RecordingIndicator {
    private var panel: NSPanel?
    private var dimWindow: NSWindow?

    /// 停止ボタン押下時のコールバック
    public var onStop: (() -> Void)?

    /// 録画範囲（macOS スクリーン座標）
    private var recordingRect: CGRect?

    public init() {}

    /// インジケーターを表示
    /// - Parameter screenRect: 録画範囲（macOS スクリーン座標）。nil の場合はハイライトなし
    public func show(screenRect: CGRect? = nil) {
        dismiss()
        self.recordingRect = screenRect

        // 録画範囲外を暗転
        if let screenRect {
            showDimOverlay(highlightRect: screenRect)
        }

        let view = RecordingIndicatorView(
            onStop: { [weak self] in
                self?.onStop?()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(NSSize(width: 160, height: 36))

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 160, height: 36)),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.contentView = hostingView
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true

        // 画面上部中央に配置
        let screenFrame = ScreenUtilities.activeVisibleFrame
        let origin = NSPoint(
            x: screenFrame.midX - 80,
            y: screenFrame.maxY - 50
        )
        p.setFrameOrigin(origin)

        p.orderFrontRegardless()
        self.panel = p
        Logger.app.info("録画インジケーター表示")
    }

    /// インジケーターを非表示
    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        dimWindow?.orderOut(nil)
        dimWindow = nil
        recordingRect = nil
    }

    // MARK: - Dim Overlay

    private func showDimOverlay(highlightRect: CGRect) {
        let screen = ScreenUtilities.screen(containing: highlightRect)
        let screenFrame = screen.frame

        let dimView = RecordingDimView(frame: NSRect(origin: .zero, size: screenFrame.size))
        // screenFrame 基準のローカル座標に変換
        dimView.highlightRect = NSRect(
            x: highlightRect.origin.x - screenFrame.origin.x,
            y: highlightRect.origin.y - screenFrame.origin.y,
            width: highlightRect.width,
            height: highlightRect.height
        )

        let win = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.contentView = dimView
        win.orderFrontRegardless()
        self.dimWindow = win
    }
}

// MARK: - Recording Dim View

/// 録画範囲以外を暗転させるビュー
private final class RecordingDimView: NSView {
    var highlightRect: NSRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        // 背景全体を暗くする
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        // 録画範囲を透明に切り抜く
        NSColor.clear.setFill()
        highlightRect.fill(using: .copy)

        // 録画範囲に赤い枠線
        NSColor.red.withAlphaComponent(0.5).setStroke()
        let path = NSBezierPath(rect: highlightRect.insetBy(dx: -1, dy: -1))
        path.lineWidth = 2
        path.stroke()
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

            Text(L10n.recording)
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
