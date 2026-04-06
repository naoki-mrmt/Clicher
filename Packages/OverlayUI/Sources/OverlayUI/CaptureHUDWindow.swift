import AppKit
import OSLog
import SwiftUI
import SharedModels
import Utilities

/// キャプチャHUDの NSPanel ウィンドウコントローラー
/// 画面中央にフローティング表示し、フェードイン/アウトで開閉する
@MainActor
public final class CaptureHUDWindow {
    private var panel: NSPanel?
    private let appState: AppState

    /// モード選択時のコールバック
    public var onModeSelected: ((CaptureMode) -> Void)?

    public init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Show / Hide

    /// HUDを表示（フェードイン）
    public func show() {
        if panel != nil {
            hide()
            return
        }

        let hudView = CaptureHUDView(
            appState: appState,
            onModeSelected: { [weak self] mode in
                self?.handleModeSelection(mode)
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )

        let hostingView = NSHostingView(rootView: hudView)
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
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        // 画面中央に配置
        let screenFrame = ScreenUtilities.activeVisibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)

        // フェードイン
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        appState.isHUDVisible = true

        // Escキー・数字キー監視
        setupLocalKeyMonitor()

        Logger.app.info("キャプチャHUDを表示")
    }

    /// HUDを非表示（フェードアウト）
    public func hide() {
        guard let panel else { return }

        removeLocalKeyMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                self?.panel = nil
                self?.appState.isHUDVisible = false
                Logger.app.info("キャプチャHUDを非表示")
            }
        }
    }

    /// 表示/非表示をトグル
    public func toggle() {
        if panel != nil {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Keyboard Monitoring

    private var localKeyMonitor: Any?

    private func setupLocalKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func removeLocalKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    /// キーイベント処理。消費した場合は true を返す
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Escape で閉じる
        if event.keyCode == 53 {
            hide()
            return true
        }

        // 数字キー 1-6 でモード選択
        if let characters = event.charactersIgnoringModifiers,
           let digit = Int(characters),
           let mode = CaptureMode(rawValue: digit) {
            handleModeSelection(mode)
            return true
        }

        return false
    }

    // MARK: - Mode Selection

    private func handleModeSelection(_ mode: CaptureMode) {
        guard mode.isAvailable else {
            Logger.app.info("モード \(mode.label) は未実装です")
            return
        }

        appState.selectedCaptureMode = mode
        hide()
        onModeSelected?(mode)
    }
}
