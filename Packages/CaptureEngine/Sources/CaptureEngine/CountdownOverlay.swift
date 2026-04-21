import AppKit
import SwiftUI
import OSLog
import Observation
import Utilities

/// カウントダウン表示用のフローティングオーバーレイ
@MainActor
public final class CountdownOverlay {
    private var panel: NSPanel?
    private var countdownState: CountdownState?

    /// 現在の残り秒数
    public private(set) var remaining = 0

    public init() {}

    /// カウントダウンを開始して表示
    public func show(seconds: Int) {
        dismiss()
        remaining = seconds

        let state = CountdownState(remaining: seconds)
        self.countdownState = state

        let view = CountdownView(state: state)
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(NSSize(width: 120, height: 120))

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 120, height: 120)),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        // 画面中央に配置
        let screenFrame = ScreenUtilities.activeVisibleFrame
        let origin = NSPoint(
            x: screenFrame.midX - 60,
            y: screenFrame.midY - 60
        )
        panel.setFrameOrigin(origin)

        panel.orderFrontRegardless()
        self.panel = panel

        Logger.capture.info("カウントダウン開始: \(seconds)秒")
    }

    /// 残り秒数を更新
    public func update(remaining: Int) {
        self.remaining = remaining
        countdownState?.remaining = remaining
    }

    /// オーバーレイを閉じる
    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        countdownState = nil
        remaining = 0
    }
}

// MARK: - CountdownState

@Observable
@MainActor
final class CountdownState {
    var remaining: Int

    init(remaining: Int) {
        self.remaining = remaining
    }
}

// MARK: - CountdownView

/// カウントダウン数字を表示する SwiftUI ビュー
struct CountdownView: View {
    let state: CountdownState

    var body: some View {
        Text("\(state.remaining)")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 100, height: 100)
            .background(.black.opacity(0.6), in: Circle())
            .contentTransition(.numericText())
    }
}
