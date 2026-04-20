import AppKit
import SwiftUI
import SharedModels
import Utilities

// MARK: - Keyable Panel

/// `canBecomeKey` を返す NSPanel サブクラス。
/// `.nonactivatingPanel` でもボタンクリックを受け付けるために必要。
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// `acceptsFirstMouse` を返す NSHostingView サブクラス。
/// 非アクティブウィンドウでも最初のクリックでボタンが反応するようにする。
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Lark 風スクロールキャプチャの操作パネル
/// 「手動スクロール / 自動スクロール / 完了 / キャンセル」を表示
@MainActor
public final class ScrollCaptureControls {
    private var panel: KeyablePanel?
    private var keyMonitor: Any?

    /// コールバック
    public var onAutoScroll: (() -> Void)?
    public var onStopAutoScroll: (() -> Void)?
    public var onFinish: (() -> Void)?
    public var onCancel: (() -> Void)?
    /// フレーム数の更新用（Bindable ではなくクロージャで更新）
    private var updateFrameCount: ((Int) -> Void)?

    public init() {}

    /// パネルを表示
    /// - Parameter screenRect: キャプチャ範囲（macOS スクリーン座標、パネル配置の基準）
    public func show(screenRect: CGRect) {
        dismiss()

        let frameCountState = FrameCountState()
        updateFrameCount = { count in
            frameCountState.count = count
        }

        let view = ScrollCaptureControlsView(
            frameCountState: frameCountState,
            onAutoScroll: { [weak self] in self?.onAutoScroll?() },
            onStopAutoScroll: { [weak self] in self?.onStopAutoScroll?() },
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
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = false
        p.acceptsMouseMovedEvents = true
        p.contentView = hostingView
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true

        // キャプチャ範囲の下に配置
        let visibleFrame = ScreenUtilities.activeVisibleFrame
        let toolbarY: CGFloat
        if screenRect.origin.y > panelSize.height + 16 {
            toolbarY = screenRect.origin.y - panelSize.height - 8
        } else {
            toolbarY = screenRect.maxY + 8
        }
        let rawX = screenRect.midX - panelSize.width / 2
        let x = max(visibleFrame.minX + 8, min(rawX, visibleFrame.maxX - panelSize.width - 8))
        p.setFrameOrigin(NSPoint(x: x, y: toolbarY))

        NSApp.activate(ignoringOtherApps: false)
        p.orderFrontRegardless()
        p.makeKey()
        self.panel = p

        // ESC でキャンセル
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onCancel?()
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    /// フレーム数を更新
    public func setFrameCount(_ count: Int) {
        updateFrameCount?(count)
    }

    /// パネルを非表示
    public func dismiss() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Observable state

@Observable
final class FrameCountState {
    var count: Int = 0
}

// MARK: - SwiftUI View

struct ScrollCaptureControlsView: View {
    let frameCountState: FrameCountState
    let onAutoScroll: () -> Void
    let onStopAutoScroll: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    @State private var isAutoScrolling = false

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
                Text(L10n.frameCount(frameCountState.count))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 60)

                // 自動スクロールトグル
                Button {
                    isAutoScrolling.toggle()
                    if isAutoScrolling {
                        onAutoScroll()
                    } else {
                        onStopAutoScroll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoScrolling ? "stop.fill" : "play.fill")
                            .font(.caption2)
                        Text(isAutoScrolling ? L10n.stopCapture : L10n.autoScroll)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        isAutoScrolling
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
