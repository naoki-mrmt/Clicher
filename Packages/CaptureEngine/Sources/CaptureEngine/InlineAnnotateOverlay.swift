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

    /// モードタブバーの選択モード（Binding 用）
    private var _selectedMode: CaptureMode = .area

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

        // 画面更新を一括で行い、段階的な表示を防ぐ
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 1. 背景暗転（まだなければ作成、隠れていれば再表示）
        if dimWindow == nil {
            showDimWindow()
        } else {
            dimWindow?.orderFrontRegardless()
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
        cw.hasShadow = false
        cw.acceptsMouseMovedEvents = true
        cw.contentView = canvas
        NSApp.activate(ignoringOtherApps: true)
        cw.orderFrontRegardless()
        cw.makeKey()
        cw.makeFirstResponder(canvas)
        self.canvasWindow = cw

        // 3. モードタブバーを非表示（エリア選択完了後はツールバーのみ）
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil

        // 4. ツールバー（キャンバスの下 or 上に配置）
        showToolbar(canvasRect: screenRect, document: doc, canvasView: canvas)

        CATransaction.commit()

        // 5. キーボードモニター
        setupKeyMonitor()

        Logger.capture.info("インラインアノテーション開始")
    }

    /// 全ウィンドウを閉じる
    public func dismiss() {
        removeKeyMonitor()
        // カーソルをデフォルトに戻す
        NSCursor.arrow.set()
        // カラーパレットが開いていれば閉じる
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderOut(nil)
        }
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
        let screen = ScreenUtilities.activeScreen

        let dw = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        dw.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        dw.isOpaque = false
        dw.backgroundColor = .clear
        dw.hasShadow = false
        dw.ignoresMouseEvents = false

        let clickView = DimClickView { [weak self] in
            self?.handleCancel()
        }
        clickView.frame = screen.frame
        clickView.wantsLayer = true
        clickView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        dw.contentView = clickView

        dw.orderFrontRegardless()
        self.dimWindow = dw
    }

    // MARK: - Toolbar

    private func showToolbar(canvasRect: CGRect, document: AnnotateDocument, canvasView: AnnotateCanvasView) {
        let toolbarView = InlineToolbarView(
            document: document,
            onUndo: { [weak document, weak canvasView] in document?.undo(); canvasView?.needsDisplay = true },
            onRedo: { [weak document, weak canvasView] in document?.redo(); canvasView?.needsDisplay = true },
            onSave: { [weak self] in self?.handleSave() },
            onCancel: { [weak self] in self?.handleCancel() },
            onDone: { [weak self] in self?.handleDone() }
        )

        let hostingView = NSHostingView(rootView: toolbarView)
        let fittingSize = hostingView.fittingSize
        let toolbarSize = fittingSize
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
        let screenFrame = ScreenUtilities.activeVisibleFrame
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
        _selectedMode = currentMode
        let binding = Binding<CaptureMode>(
            get: { [weak self] in self?._selectedMode ?? .area },
            set: { [weak self] in self?._selectedMode = $0 }
        )
        let tabView = ModeTabBarView(
            selectedMode: binding,
            onModeSelected: { [weak self] mode in
                self?._selectedMode = mode
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
        let screenFrame = ScreenUtilities.activeScreenFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - panel.frame.height - 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))

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

    /// 背景暗転を一時的に非表示にする（エリア選択中の二重暗転を防ぐ）
    public func hideDim() {
        dimWindow?.orderOut(nil)
    }

    /// 背景暗転を再表示する
    public func showDim() {
        dimWindow?.orderFrontRegardless()
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
        // グローバルモニター（アプリが非アクティブ時のみ Esc を捕捉）
        // ローカルモニターと二重発火しないよう、アプリが非アクティブ時のみ処理
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            guard !NSApp.isActive else { return }
            self?.handleCancel()
        }
    }

    public func removeKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }

    // MARK: - Recording Ready

    /// 録画待機状態を表示（エリア選択後、開始ボタン押下待ち）
    public func showRecordingReady(screenRect: CGRect, onStart: @escaping () -> Void, onCancel: @escaping () -> Void) {
        // 既存のキャンバス/ツールバーをクリア
        canvasWindow?.orderOut(nil)
        canvasWindow = nil
        toolbarWindow?.orderOut(nil)
        toolbarWindow = nil

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 背景暗転
        if dimWindow == nil {
            showDimWindow()
        } else {
            dimWindow?.orderFrontRegardless()
        }

        // 選択範囲のハイライト枠（録画対象を視覚的に示す）
        let highlightView = RecordingHighlightView(frame: NSRect(origin: .zero, size: screenRect.size))
        let cw = KeyableBorderlessWindow(
            contentRect: NSRect(origin: screenRect.origin, size: screenRect.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        cw.level = .screenSaver
        cw.isOpaque = false
        cw.backgroundColor = .clear
        cw.hasShadow = false
        cw.contentView = highlightView
        cw.orderFrontRegardless()
        self.canvasWindow = cw

        // モードタブを非表示
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil

        // 録画開始ツールバー
        let toolbarView = RecordingReadyToolbarView(
            onStart: { [weak self] in
                self?.dismiss()
                onStart()
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )
        let hostingView = NSHostingView(rootView: toolbarView)
        let fittingSize = hostingView.fittingSize
        let toolbarSize = NSSize(width: max(fittingSize.width, 200), height: fittingSize.height)
        hostingView.setFrameSize(toolbarSize)

        let spaceBelow = screenRect.origin.y
        let toolbarY: CGFloat
        if spaceBelow >= toolbarSize.height + 16 {
            toolbarY = screenRect.origin.y - toolbarSize.height - 8
        } else {
            toolbarY = screenRect.maxY + 8
        }

        let visibleFrame = ScreenUtilities.activeVisibleFrame
        let rawX = screenRect.midX - toolbarSize.width / 2
        let toolbarX = max(visibleFrame.minX + 8, min(rawX, visibleFrame.maxX - toolbarSize.width - 8))

        let panel = NSPanel(
            contentRect: NSRect(origin: NSPoint(x: toolbarX, y: toolbarY), size: toolbarSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.orderFrontRegardless()
        self.toolbarWindow = panel

        CATransaction.commit()

        setupKeyMonitor()
        // ESC でキャンセル
        self.onCancel = {
            onCancel()
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
                .accessibilityLabel(tool.label)
            }

            Divider()
                .frame(height: 20)

            // 色選択
            ColorPicker("", selection: strokeColorBinding)
                .labelsHidden()
                .frame(width: 28)

            // 線幅スライダー
            HStack(spacing: 4) {
                Image(systemName: "lineweight")
                    .font(.caption)
                Slider(
                    value: Bindable(document).currentStyle.lineWidth,
                    in: 1...20,
                    step: 1
                )
                .frame(width: 60)
                Text("\(Int(document.currentStyle.lineWidth))")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 16)
            }
            .accessibilityLabel("Line width")

            Spacer()

            // Undo / Redo
            Button { onUndo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!document.canUndo)
            .accessibilityLabel("Undo")

            Button { onRedo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!document.canRedo)
            .accessibilityLabel("Redo")

            Divider()
                .frame(height: 20)

            // 保存
            Button { onSave() } label: {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L10n.annotateSave)
            .accessibilityLabel(L10n.annotateSave)

            // キャンセル
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L10n.annotateCancel)
            .accessibilityLabel(L10n.annotateCancel)

            // 完了（コピー）
            Button { onDone() } label: {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .fontWeight(.bold)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L10n.annotateDone)
            .accessibilityLabel(L10n.annotateDone)
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
    @Binding var selectedMode: CaptureMode
    let onModeSelected: (CaptureMode) -> Void

    init(selectedMode: Binding<CaptureMode>, onModeSelected: @escaping (CaptureMode) -> Void) {
        self._selectedMode = selectedMode
        self.onModeSelected = onModeSelected
    }

    private var modes: [(CaptureMode, String)] {
        [
            (.area, L10n.screenshot),
            (.scroll, L10n.scrollCapture),
            (.recording, L10n.screenRecording),
            (.ocr, L10n.recognizeText),
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.0) { mode, label in
                Button {
                    selectedMode = mode
                    onModeSelected(mode)
                } label: {
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

// MARK: - Recording Ready Toolbar

struct RecordingReadyToolbarView: View {
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // キャンセル
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.cancel)

            Spacer()

            // 録画開始ボタン
            Button { onStart() } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                    Text(L10n.startRecording)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.startRecording)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 0.5))
    }
}

// MARK: - Recording Highlight View

/// 録画対象エリアのハイライト枠（赤い点線）
private final class RecordingHighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.withAlphaComponent(0.6).setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5))
        path.lineWidth = 3
        let pattern: [CGFloat] = [6, 4]
        path.setLineDash(pattern, count: pattern.count, phase: 0)
        path.stroke()
    }
}
