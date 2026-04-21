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

    /// 現在のキャプチャ範囲（モード切替時に渡す）
    private(set) var currentMacRect: CGRect = .zero

    /// 完了時のコールバック（編集済み画像）
    public var onComplete: ((CGImage) -> Void)?

    /// 保存時のコールバック
    public var onSave: ((CGImage) -> Void)?

    /// キャンセル時のコールバック
    public var onCancel: (() -> Void)?

    /// モード切替: スクロールキャプチャ（macRect）
    public var onSwitchToScroll: ((CGRect) -> Void)?

    /// モード切替: 録画（macRect）
    public var onSwitchToRecord: ((CGRect) -> Void)?

    /// OCR 実行（元画像）
    public var onRunOCR: ((CGImage) -> Void)?

    /// ピン留め（編集済み画像）
    public var onPinImage: ((CGImage) -> Void)?

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
        document = nil
        canvasView = nil
        removeKeyMonitor()

        self.currentMacRect = screenRect

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

        // 3. ツールバー（キャンバスの下 or 上に配置）
        showToolbar(canvasRect: screenRect, document: doc, canvasView: canvas)

        // 4. モードタブバー（画面上部、モード切替用）
        showModeTabBar()

        CATransaction.commit()

        // 5. キーボードモニター
        setupKeyMonitor()

        Logger.capture.info("インラインアノテーション開始")
    }

    /// 全ウィンドウを閉じる
    public func dismiss() {
        removeKeyMonitor()
        NSCursor.arrow.set()
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
            onDone: { [weak self] in self?.handleDone() },
            onPin: { [weak self] in self?.handlePinImage() }
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

    private func showModeTabBar() {
        modeTabWindow?.orderOut(nil)
        modeTabWindow = nil

        let tabView = ModeTabBarView(
            initialMode: .area,
            onModeSelected: { [weak self] mode in
                guard let self else { return }
                switch mode {
                case .area:
                    break // 既にスクリーンショットモード
                case .scroll:
                    handleSwitchToScroll()
                case .recording:
                    handleSwitchToRecord()
                case .ocr:
                    handleRunOCR()
                default:
                    break
                }
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

        let screenFrame = ScreenUtilities.activeScreenFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - panel.frame.height - 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.orderFrontRegardless()
        self.modeTabWindow = panel
    }

    /// 背景暗転を一時的に非表示にする（キャプチャ前の二重暗転を防ぐ）
    public func hideDim() {
        dimWindow?.orderOut(nil)
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
    public func showRecordingReady(screenRect: CGRect, onStart: @escaping (RecordingAudioSettings) -> Void, onCancel: @escaping () -> Void) {
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

        // 録画開始ツールバー
        let toolbarView = RecordingReadyToolbarView(
            onStart: { [weak self] audioSettings in
                self?.dismiss()
                onStart(audioSettings)
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

    private func handleSwitchToScroll() {
        let macRect = currentMacRect
        let callback = onSwitchToScroll
        dismiss()
        callback?(macRect)
    }

    private func handleSwitchToRecord() {
        let macRect = currentMacRect
        // onCancel を退避（showRecordingReady が上書きするため）
        let originalCancel = onCancel
        showRecordingReady(
            screenRect: macRect,
            onStart: { [weak self] _ in
                self?.onSwitchToRecord?(macRect)
            },
            onCancel: { [weak self] in
                guard let self else { return }
                // handleCancel() を呼ばない（再帰防止）
                originalCancel?()
                dismiss()
            }
        )
    }

    private func handleRunOCR() {
        guard let image = document?.originalImage else { return }
        onRunOCR?(image)
    }

    private func handlePinImage() {
        guard let image = canvasView?.exportImage() else { return }
        onPinImage?(image)
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
    let onPin: () -> Void

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

            // 色選択（Lark 風スウォッチ）
            ColorSwatchPicker(selection: strokeColorBinding)

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

            // ピン留め
            Button { onPin() } label: {
                Image(systemName: "pin")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Pin")
            .accessibilityLabel("Pin")

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
                Image(systemName: "doc.on.doc")
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
    @State private var selectedMode: CaptureMode
    let onModeSelected: (CaptureMode) -> Void

    init(initialMode: CaptureMode, onModeSelected: @escaping (CaptureMode) -> Void) {
        self._selectedMode = State(initialValue: initialMode)
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

/// 録画の音声設定
public struct RecordingAudioSettings {
    public var capturesSystemAudio: Bool
    public var capturesMicrophone: Bool

    public init(capturesSystemAudio: Bool = true, capturesMicrophone: Bool = false) {
        self.capturesSystemAudio = capturesSystemAudio
        self.capturesMicrophone = capturesMicrophone
    }
}

struct RecordingReadyToolbarView: View {
    let onStart: (RecordingAudioSettings) -> Void
    let onCancel: () -> Void

    @State private var capturesSystemAudio = true
    @State private var capturesMicrophone = false

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

            // 音声トグル
            audioToggle(
                icon: "speaker.wave.2.fill",
                label: L10n.systemAudio,
                isOn: $capturesSystemAudio
            )

            audioToggle(
                icon: "mic.fill",
                label: L10n.microphone,
                isOn: $capturesMicrophone
            )

            Spacer()

            // 録画開始ボタン
            Button {
                onStart(RecordingAudioSettings(
                    capturesSystemAudio: capturesSystemAudio,
                    capturesMicrophone: capturesMicrophone
                ))
            } label: {
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

    private func audioToggle(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundStyle(isOn.wrappedValue ? .primary : .tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isOn.wrappedValue
                    ? AnyShapeStyle(.white.opacity(0.12))
                    : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Color Swatch Picker (Lark-style)

/// Lark 風のカラースウォッチピッカー
/// プリセット色のスウォッチを横並びで表示し、カスタムカラーピッカーも開ける
struct ColorSwatchPicker: View {
    @Binding var selection: Color
    @State private var colorPanelTarget = ColorPanelTarget()

    /// プリセットカラー（Lark 風の配色 / システムカラーで統一）
    private static let presetColors: [Color] = [
        Color(nsColor: .systemRed),
        Color(nsColor: .systemOrange),
        Color(nsColor: .systemYellow),
        Color(nsColor: .systemGreen),
        Color(nsColor: .systemBlue),
        Color(nsColor: .systemPurple),
        Color(nsColor: .black),
        Color(nsColor: .white),
    ]

    @State private var showCustomPicker = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.presetColors, id: \.self) { color in
                swatch(color: color)
            }
            // カスタムカラーピッカー（スウォッチと統一した円形ボタン）
            Button {
                NSColorPanel.shared.setTarget(nil)
                NSColorPanel.shared.setAction(nil)
                NSColorPanel.shared.color = NSColor(selection)
                NSColorPanel.shared.orderFront(nil)
                // パネルの色変更を監視
                NSColorPanel.shared.setTarget(colorPanelTarget)
                NSColorPanel.shared.setAction(#selector(ColorPanelTarget.colorChanged(_:)))
                colorPanelTarget.binding = $selection
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                                center: .center
                            )
                        )
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(selection)
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)
            .help("Custom color")
        }
    }

    private func swatch(color: Color) -> some View {
        let isSelected = isColorEqual(selection, color)
        return Button {
            selection = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.5)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                        .padding(-2)
                )
        }
        .buttonStyle(.plain)
        .help(colorLabel(color))
    }

    /// Color を NSColor 経由で比較（SwiftUI の Color 直接比較が不安定なため）
    private func isColorEqual(_ a: Color, _ b: Color) -> Bool {
        let nsA = NSColor(a).usingColorSpace(.sRGB)
        let nsB = NSColor(b).usingColorSpace(.sRGB)
        guard let nsA, let nsB else { return false }
        let ep: CGFloat = 0.02
        return abs(nsA.redComponent - nsB.redComponent) < ep
            && abs(nsA.greenComponent - nsB.greenComponent) < ep
            && abs(nsA.blueComponent - nsB.blueComponent) < ep
    }

    private func colorLabel(_ color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB)
        guard let ns else { return "" }
        let presets: [(NSColor, String)] = [
            (.systemRed, "Red"),
            (.systemOrange, "Orange"),
            (.systemYellow, "Yellow"),
            (.systemGreen, "Green"),
            (.systemBlue, "Blue"),
            (.systemPurple, "Purple"),
            (.black, "Black"),
            (.white, "White"),
        ]
        let ep: CGFloat = 0.02
        for (c, name) in presets {
            guard let cc = c.usingColorSpace(.sRGB) else { continue }
            if abs(cc.redComponent - ns.redComponent) < ep
                && abs(cc.greenComponent - ns.greenComponent) < ep
                && abs(cc.blueComponent - ns.blueComponent) < ep {
                return name
            }
        }
        return ""
    }
}

// MARK: - Color Panel Target

/// NSColorPanel のアクションを SwiftUI Binding に橋渡しするヘルパー
@MainActor
final class ColorPanelTarget: NSObject {
    var binding: Binding<Color>?

    @objc func colorChanged(_ sender: NSColorPanel) {
        binding?.wrappedValue = Color(nsColor: sender.color)
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
