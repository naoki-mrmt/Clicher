import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities

/// フローティングスクリーンショットの設定
public struct FloatingScreenshotConfig: Sendable {
    public var opacity: Double
    public var isClickThrough: Bool
    public var isAlwaysOnTop: Bool

    public init(
        opacity: Double = 1.0,
        isClickThrough: Bool = false,
        isAlwaysOnTop: Bool = true
    ) {
        self.opacity = opacity
        self.isClickThrough = isClickThrough
        self.isAlwaysOnTop = isAlwaysOnTop
    }
}

/// フローティングスクリーンショットの管理（複数表示対応）
@Observable
@MainActor
public final class FloatingScreenshotManager {
    /// 現在表示中のウィンドウ
    public private(set) var windows: [FloatingScreenshotWindow] = []

    public init() {}

    /// スクリーンショットをピン留め表示
    public func pin(result: CaptureResult, config: FloatingScreenshotConfig = FloatingScreenshotConfig()) {
        let window = FloatingScreenshotWindow(result: result, config: config)
        window.onClose = { [weak self] id in
            self?.windows.removeAll { $0.id == id }
        }
        window.onConfigChange = { [weak self] id, newConfig in
            self?.updateConfig(id: id, config: newConfig)
        }
        window.show()
        windows.append(window)
        Logger.app.info("フローティングスクリーンショットを表示 (合計: \(self.windows.count))")
    }

    /// 全ウィンドウを閉じる
    public func closeAll() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
    }

    private func updateConfig(id: UUID, config: FloatingScreenshotConfig) {
        guard let window = windows.first(where: { $0.id == id }) else { return }
        window.applyConfig(config)
    }
}

/// 個別のフローティングスクリーンショットウィンドウ
@MainActor
public final class FloatingScreenshotWindow: Identifiable {
    public let id = UUID()
    private var panel: NSPanel?
    /// クリックスルー時に操作を受け付ける小さいグリップウィンドウ
    private var gripPanel: NSPanel?
    private var config: FloatingScreenshotConfig

    var onClose: ((UUID) -> Void)?
    var onConfigChange: ((UUID, FloatingScreenshotConfig) -> Void)?

    init(result: CaptureResult, config: FloatingScreenshotConfig) {
        self.config = config

        let imageSize = CGSize(
            width: CGFloat(result.image.width) / 2,
            height: CGFloat(result.image.height) / 2
        )

        let view = FloatingScreenshotView(
            image: result.nsImage,
            config: config,
            onOpacityChange: { [weak self] opacity in
                guard let self else { return }
                var newConfig = self.config
                newConfig.opacity = opacity
                self.config = newConfig
                self.panel?.alphaValue = opacity
            },
            onClickThroughToggle: { [weak self] enabled in
                guard let self else { return }
                var newConfig = self.config
                newConfig.isClickThrough = enabled
                self.config = newConfig
                self.panel?.ignoresMouseEvents = enabled
                self.updateGripPanel(clickThrough: enabled)
            },
            onClose: { [weak self] in
                guard let self else { return }
                self.close()
                self.onClose?(self.id)
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let panelSize = NSSize(
            width: max(imageSize.width, 200),
            height: max(imageSize.height, 150) + 32
        )
        hostingView.setFrameSize(panelSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = config.isAlwaysOnTop ? .floating : .normal
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.title = "Clicher Pin"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.alphaValue = config.opacity

        self.panel = panel
    }

    func show() {
        panel?.center()
        panel?.orderFrontRegardless()
    }

    func close() {
        gripPanel?.orderOut(nil)
        gripPanel = nil
        panel?.orderOut(nil)
        panel = nil
    }

    func applyConfig(_ config: FloatingScreenshotConfig) {
        self.config = config
        panel?.alphaValue = config.opacity
        panel?.ignoresMouseEvents = config.isClickThrough
        panel?.level = config.isAlwaysOnTop ? .floating : .normal
        updateGripPanel(clickThrough: config.isClickThrough)
    }

    /// クリックスルー時にパネル右上に復帰用グリップを表示
    private func updateGripPanel(clickThrough: Bool) {
        if clickThrough {
            showGripPanel()
        } else {
            gripPanel?.orderOut(nil)
            gripPanel = nil
        }
    }

    private func showGripPanel() {
        guard let panel else { return }
        gripPanel?.orderOut(nil)

        let gripSize = NSSize(width: 28, height: 28)
        let gripOrigin = NSPoint(
            x: panel.frame.maxX - gripSize.width - 4,
            y: panel.frame.maxY - gripSize.height - 4
        )
        let grip = NSPanel(
            contentRect: NSRect(origin: gripOrigin, size: gripSize),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        grip.level = panel.level + 1
        grip.isOpaque = false
        grip.backgroundColor = .clear
        grip.hasShadow = false
        grip.ignoresMouseEvents = false

        let button = NSButton(frame: NSRect(origin: .zero, size: gripSize))
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Disable click-through")
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.8).cgColor
        button.layer?.cornerRadius = gripSize.width / 2
        button.target = self
        button.action = #selector(disableClickThrough)
        grip.contentView = button

        grip.orderFrontRegardless()
        self.gripPanel = grip
    }

    @objc private func disableClickThrough() {
        var newConfig = config
        newConfig.isClickThrough = false
        config = newConfig
        panel?.ignoresMouseEvents = false
        gripPanel?.orderOut(nil)
        gripPanel = nil
        onConfigChange?(id, config)
    }
}

// MARK: - SwiftUI View

struct FloatingScreenshotView: View {
    let image: NSImage
    let config: FloatingScreenshotConfig
    let onOpacityChange: (Double) -> Void
    let onClickThroughToggle: (Bool) -> Void
    let onClose: () -> Void

    @State private var opacity: Double
    @State private var isClickThrough: Bool
    @State private var showControls = false

    init(
        image: NSImage,
        config: FloatingScreenshotConfig,
        onOpacityChange: @escaping (Double) -> Void,
        onClickThroughToggle: @escaping (Bool) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.image = image
        self.config = config
        self.onOpacityChange = onOpacityChange
        self.onClickThroughToggle = onClickThroughToggle
        self.onClose = onClose
        _opacity = State(initialValue: config.opacity)
        _isClickThrough = State(initialValue: config.isClickThrough)
    }

    var body: some View {
        VStack(spacing: 0) {
            // コントロールバー（ホバー時表示）
            if showControls {
                controlBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 画像
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .onHover { showControls = $0 }
        .animation(.easeInOut(duration: 0.15), value: showControls)
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            // 不透明度スライダー
            Image(systemName: "circle.lefthalf.filled")
                .font(.caption2)
            Slider(value: $opacity, in: 0.2...1.0) { _ in
                onOpacityChange(opacity)
            }
            .frame(width: 80)
            .accessibilityLabel(L10n.opacity)

            Divider().frame(height: 12)

            // クリックスルー
            Toggle(isOn: $isClickThrough) {
                Image(systemName: "cursorarrow.click.badge.clock")
                    .font(.caption2)
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel(L10n.clickThrough)
            .onChange(of: isClickThrough) { _, newValue in
                onClickThroughToggle(newValue)
            }

            Spacer()

            // 閉じる
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.cancel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }
}
