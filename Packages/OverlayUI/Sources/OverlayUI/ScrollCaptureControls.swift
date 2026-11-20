import AppKit
import SwiftUI
import SharedModels
import Utilities

/// Lark 風スクロールキャプチャの操作パネル
/// 「手動スクロール / 自動スクロール / 完了 / キャンセル」を表示
@MainActor
public final class ScrollCaptureControls {
    private var panel: KeyablePanel?
    private var highlightWindow: NSWindow?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var controlsState: ControlsState?

    /// コールバック
    public var onAutoScroll: (() -> Void)?
    public var onStopAutoScroll: (() -> Void)?
    public var onFinish: (() -> Void)?
    public var onCancel: (() -> Void)?

    public init() {}

    /// パネルを表示
    /// - Parameter screenRect: キャプチャ範囲（macOS スクリーン座標、パネル配置の基準）
    public func show(screenRect: CGRect) {
        dismiss()

        // 1. キャプチャ範囲のハイライト枠
        showHighlight(screenRect: screenRect)

        // 2. 操作パネル
        let state = ControlsState()
        self.controlsState = state

        let view = ScrollCaptureControlsView(
            state: state,
            onAutoScroll: { [weak self, weak state] in
                state?.isAutoScrolling = true
                self?.onAutoScroll?()
            },
            onStopAutoScroll: { [weak self, weak state] in
                state?.isAutoScrolling = false
                self?.onStopAutoScroll?()
            },
            onFinish: { [weak self] in
                self?.onFinish?()
                self?.dismiss()
            },
            onCancel: { [weak self] in
                self?.onCancel?()
                self?.dismiss()
            }
        )

        let hostingView = FirstMouseHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize
        let panelSize = NSSize(width: max(fittingSize.width, 300), height: fittingSize.height)
        hostingView.setFrameSize(panelSize)

        let p = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // 対象ウィンドウより前面・別アプリのフローティングより前面で確実に見えるように
        p.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = false
        p.acceptsMouseMovedEvents = true
        p.contentView = hostingView
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        // スクロールキャプチャ画像にパネルが映り込まないように除外
        p.sharingType = .none

        // パネル位置: 下 → 上 → 範囲内下部 の順でフォールバック、最後に画面内へクランプ
        let visibleFrame = ScreenUtilities.activeVisibleFrame
        let spaceBelow = screenRect.origin.y - visibleFrame.minY
        let spaceAbove = visibleFrame.maxY - screenRect.maxY

        let toolbarY: CGFloat
        if spaceBelow >= panelSize.height + 16 {
            toolbarY = screenRect.origin.y - panelSize.height - 8
        } else if spaceAbove >= panelSize.height + 16 {
            toolbarY = screenRect.maxY + 8
        } else {
            // どちらにも入らない場合は範囲内の下部に重ねる（オフスクリーン回避優先）
            toolbarY = screenRect.origin.y + 8
        }

        let rawX = screenRect.midX - panelSize.width / 2
        let x = max(visibleFrame.minX + 8, min(rawX, visibleFrame.maxX - panelSize.width - 8))
        let clampedY = max(visibleFrame.minY + 8, min(toolbarY, visibleFrame.maxY - panelSize.height - 8))
        p.setFrameOrigin(NSPoint(x: x, y: clampedY))

        NSApp.activate(ignoringOtherApps: true)
        p.orderFrontRegardless()
        p.makeKey()
        self.panel = p

        // ESC でキャンセル
        // Clicher がアクティブ時はローカル、別アプリにフォーカスが渡った場合はグローバルで拾う
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onCancel?()
                self?.dismiss()
                return nil
            }
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            self?.onCancel?()
            self?.dismiss()
        }
    }

    // MARK: - Highlight

    /// 選択範囲を示すハイライト枠を表示
    /// `sharingType = .none` でキャプチャ対象外なので、内側に枠を描いて問題ない
    private func showHighlight(screenRect: CGRect) {
        let window = NSWindow(
            contentRect: screenRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        // スクロールキャプチャ画像にハイライトが映り込まないように除外
        window.sharingType = .none

        let view = ScrollHighlightView(frame: NSRect(origin: .zero, size: screenRect.size))
        window.contentView = view
        window.orderFrontRegardless()
        self.highlightWindow = window
    }

    /// フレーム数を更新
    public func setFrameCount(_ count: Int) {
        controlsState?.frameCount = count
    }

    /// 自動スクロール状態を外部から更新（終端検出やキャンセル等でセッション側から呼ぶ）
    public func setAutoScrolling(_ value: Bool) {
        controlsState?.isAutoScrolling = value
    }

    /// パネルを非表示
    public func dismiss() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        highlightWindow?.orderOut(nil)
        highlightWindow = nil
        panel?.orderOut(nil)
        panel = nil
        controlsState = nil
    }
}

// MARK: - Scroll Highlight View

/// スクロールキャプチャの選択範囲を示すハイライト枠（青い実線）
/// 親ウィンドウに `sharingType = .none` が設定されているため、キャプチャ画像には写り込まない
private final class ScrollHighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let strokeWidth: CGFloat = 2
        let path = NSBezierPath(rect: bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2))
        path.lineWidth = strokeWidth
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }
}

// MARK: - Observable state

/// 操作パネルの共有状態（フレーム数 + 自動スクロール状態）
@Observable
@MainActor
final class ControlsState {
    var frameCount: Int = 0
    var isAutoScrolling: Bool = false
}

// MARK: - SwiftUI View

struct ScrollCaptureControlsView: View {
    let state: ControlsState
    let onAutoScroll: () -> Void
    let onStopAutoScroll: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 説明テキスト
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(.secondary)
                Text(L10n.scrollSlowly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                // キャンセル
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.cancel)

                // フレーム数表示
                Text(L10n.frameCount(state.frameCount))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 60)

                // 自動スクロールトグル
                Button {
                    if state.isAutoScrolling {
                        onStopAutoScroll()
                    } else {
                        onAutoScroll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: state.isAutoScrolling ? "stop.fill" : "play.fill")
                            .font(.caption2)
                        Text(state.isAutoScrolling ? L10n.stopCapture : L10n.autoScroll)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        state.isAutoScrolling
                            ? AnyShapeStyle(.red.opacity(0.15))
                            : AnyShapeStyle(.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 5)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                // 完了ボタン
                Button {
                    onFinish()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text(L10n.done)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                    .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 0.5))
    }
}
