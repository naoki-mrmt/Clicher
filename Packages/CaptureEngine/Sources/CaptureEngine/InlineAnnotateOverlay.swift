import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities
import AnnotateEngine

/// インラインアノテーションオーバーレイ（Lark 風）
/// キャプチャ直後に選択範囲上でアノテーション編集を行う
@MainActor
public final class InlineAnnotateOverlay {
    private var dimWindow: NSWindow?
    private var canvasWindow: NSWindow?
    private var toolbarWindow: NSPanel?
    private var modeTabWindow: NSPanel?
    private var document: AnnotateDocument?
    private var canvasView: AnnotateCanvasView?
    nonisolated(unsafe) private var localKeyMonitor: Any?
    nonisolated(unsafe) private var globalKeyMonitor: Any?

    /// 完了時のコールバック（編集済み画像）
    public var onComplete: ((CGImage) -> Void)?

    /// 保存時のコールバック
    public var onSave: ((CGImage) -> Void)?

    /// キャンセル時のコールバック
    public var onCancel: (() -> Void)?

    /// モード変更時のコールバック
    public var onModeChanged: ((CaptureMode) -> Void)?

    public init() {}

    deinit {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Show

    /// キャプチャ画像をインライン編集モードで表示
    /// - Parameters:
    ///   - image: キャプチャされた画像
    ///   - screenRect: 画面上の選択範囲（macOS 座標系、左下原点）
    ///   - showModeTab: モードタブバーを表示するか
    ///   - currentMode: 現在のモード（モードタブのハイライト用）
    public func show(image: CGImage, screenRect: CGRect) {
        // 既存のキャンバス/ツールバーのみクリア（dim は維持）
        canvasWindow?.orderOut(nil)
        canvasWindow = nil
        toolbarWindow?.orderOut(nil)
        toolbarWindow = nil
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil
        document = nil
        canvasView = nil
        removeKeyMonitor()

        let doc = AnnotateDocument(image: image)
        self.document = doc

        // 1. 背景暗転（まだなければ作成）
        if dimWindow == nil {
            showDimWindow()
        }

        // 2. キャンバスウィンドウ（選択範囲にぴったり配置）
        let canvas = AnnotateCanvasView(
            frame: NSRect(origin: .zero, size: screenRect.size)
        )
        canvas.document = doc
        self.canvasView = canvas

        let cw = KeyableBorderlessWindow(
            contentRect: NSRect(origin: screenRect.origin, size: screenRect.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        cw.level = .screenSaver
        cw.isOpaque = false
        cw.backgroundColor = .clear
        cw.hasShadow = true
        cw.contentView = canvas
        cw.orderFrontRegardless()
        cw.makeKey()
        self.canvasWindow = cw

        // 3. モードタブバーを非表示（エリア選択完了後はツールバーのみ）
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil

        // 4. ツールバー（キャンバスの下 or 上に配置）
        showToolbar(canvasRect: screenRect, document: doc, canvasView: canvas)

        // 5. キーボードモニター
        setupKeyMonitor()

        Logger.capture.info("インラインアノテーション開始")
    }

    /// 全ウィンドウを閉じる
    public func dismiss() {
        removeKeyMonitor()
        dimWindow?.orderOut(nil)
        dimWindow = nil
        canvasWindow?.orderOut(nil)
        canvasWindow = nil
        toolbarWindow?.orderOut(nil)
        toolbarWindow = nil
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil
        document = nil
        canvasView = nil
    }

    // MARK: - Dim Window

    private func showDimWindow() {
        guard let screen = NSScreen.main else { return }

        let dw = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        dw.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        dw.isOpaque = false
        dw.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        dw.hasShadow = false
        dw.ignoresMouseEvents = true // キャンバスへのクリックを通す

        dw.orderFrontRegardless()
        self.dimWindow = dw
    }

    // MARK: - Toolbar

    private func showToolbar(canvasRect: CGRect, document: AnnotateDocument, canvasView: AnnotateCanvasView) {
        let toolbarView = InlineToolbarView(
            document: document,
            onUndo: { [weak canvasView] in document.undo(); canvasView?.needsDisplay = true },
            onRedo: { [weak canvasView] in document.redo(); canvasView?.needsDisplay = true },
            onSave: { [weak self] in self?.handleSave() },
            onCancel: { [weak self] in self?.handleCancel() },
            onDone: { [weak self] in self?.handleDone() }
        )

        let hostingView = NSHostingView(rootView: toolbarView)
        let fittingSize = hostingView.fittingSize
        let toolbarSize = NSSize(width: max(fittingSize.width, 480), height: fittingSize.height)
        hostingView.setFrameSize(toolbarSize)

        // macOS 座標（左下原点）: origin.y が小さい = 画面下部
        // 下にスペースがあれば下に、なければ上に配置
        let spaceBelow = canvasRect.origin.y
        let toolbarY: CGFloat
        if spaceBelow >= toolbarSize.height + 16 {
            toolbarY = canvasRect.origin.y - toolbarSize.height - 8
        } else {
            toolbarY = canvasRect.maxY + 8
        }

        // キャンバスの中央に揃える + 画面内にクランプ
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let rawX = canvasRect.midX - toolbarSize.width / 2
        let toolbarX = max(screenFrame.minX + 8, min(rawX, screenFrame.maxX - toolbarSize.width - 8))
        let clampedY = max(screenFrame.minY + 8, min(toolbarY, screenFrame.maxY - toolbarSize.height - 8))

        let panel = NSPanel(
            contentRect: NSRect(
                origin: NSPoint(x: toolbarX, y: clampedY),
                size: toolbarSize
            ),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.orderFrontRegardless()
        self.toolbarWindow = panel
    }

    // MARK: - Mode Tab Bar

    private func showModeTabBar(currentMode: CaptureMode) {
        let tabView = ModeTabBarView(
            selectedMode: currentMode,
            onModeSelected: { [weak self] mode in
                self?.onModeChanged?(mode)
            }
        )

        let hostingView = NSHostingView(rootView: tabView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        // 画面上部中央
        if let screen = NSScreen.main {
            let x = screen.frame.midX - panel.frame.width / 2
            let y = screen.frame.maxY - panel.frame.height - 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.modeTabWindow = panel
    }

    /// モードタブバーのみ表示（エリア選択前の状態）
    public func showModeTabOnly(currentMode: CaptureMode = .area) {
        dismiss()
        showDimWindow()
        showModeTabBar(currentMode: currentMode)
        setupKeyMonitor()
    }

    /// モードタブバーを非表示にする
    public func hideModeTab() {
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil
    }

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        removeKeyMonitor()
        // ローカルモニター（アプリがアクティブ時）
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.handleCancel()
                return nil
            }
            return event
        }
        // グローバルモニター（アプリが非アクティブ時にも Esc を捕捉）
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.handleCancel()
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }

    // MARK: - Actions

    private func handleDone() {
        guard let image = canvasView?.exportImage() else { return }
        ImageExporter.copyToClipboard(image)
        onComplete?(image)
        dismiss()
        Logger.capture.info("インラインアノテーション完了（コピー）")
    }

    private func handleSave() {
        guard let image = canvasView?.exportImage() else { return }
        onSave?(image)
        dismiss()
        Logger.capture.info("インラインアノテーション完了（保存）")
    }

    private func handleCancel() {
        onCancel?()
        dismiss()
        Logger.capture.info("インラインアノテーションキャンセル")
    }
}

// MARK: - Dim Click View

private final class DimClickView: NSView {
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }
}

// MARK: - Keyable Borderless Window

/// borderless でもキーボード入力を受け付ける NSWindow サブクラス
private final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Inline Toolbar View

struct InlineToolbarView: View {
    let document: AnnotateDocument
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // ツール選択
            ForEach(inlineTools, id: \.self) { tool in
                Button {
                    document.currentTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    document.currentTool == tool
                        ? AnyShapeStyle(.white.opacity(0.2))
                        : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .help(tool.label)
            }

            Divider()
                .frame(height: 20)

            // 色選択
            ColorPicker("", selection: strokeColorBinding)
                .labelsHidden()
                .frame(width: 28)

            // 線幅
            Menu {
                ForEach([2, 4, 6, 8], id: \.self) { width in
                    Button("\(width)pt") {
                        document.currentStyle.lineWidth = CGFloat(width)
                    }
                }
            } label: {
                Image(systemName: "lineweight")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)

            Spacer()

            // Undo / Redo
            Button { onUndo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!document.canUndo)

            Button { onRedo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!document.canRedo)

            Divider()
                .frame(height: 20)

            // 保存
            Button { onSave() } label: {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("保存")

            // キャンセル
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("キャンセル")

            // 完了（コピー）
            Button { onDone() } label: {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .fontWeight(.bold)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("クリップボードにコピー")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 0.5))
    }

    private var inlineTools: [AnnotationToolType] {
        [.rectangle, .ellipse, .arrow, .pencil, .text, .pixelate, .highlight, .counter]
    }

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: document.currentStyle.strokeColor) },
            set: { document.currentStyle.strokeColor = NSColor($0) }
        )
    }
}

// MARK: - Mode Tab Bar View

struct ModeTabBarView: View {
    let selectedMode: CaptureMode
    let onModeSelected: (CaptureMode) -> Void

    private let modes: [(CaptureMode, String)] = [
        (.area, "スクリーンショット"),
        (.scroll, "スクロールキャプチャ"),
        (.recording, "画面収録"),
        (.ocr, "テキストを認識"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.0) { mode, label in
                Button { onModeSelected(mode) } label: {
                    Text(label)
                        .font(.system(size: 13, weight: mode == selectedMode ? .semibold : .regular))
                        .foregroundStyle(mode == selectedMode ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            mode == selectedMode
                                ? AnyShapeStyle(.white.opacity(0.15))
                                : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 0.5))
    }
}
