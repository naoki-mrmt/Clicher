import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities
import AnnotateEngine

/// インラインアノテーションオーバーレイ
/// キャプチャ直後に選択範囲上でアノテーション編集を行う（Lark 風）
@MainActor
public final class InlineAnnotateOverlay {
    private var window: NSWindow?
    private var toolbarWindow: NSPanel?
    private var document: AnnotateDocument?

    /// 完了時のコールバック（編集済み画像）
    public var onComplete: ((CGImage) -> Void)?

    /// 保存時のコールバック
    public var onSave: ((CGImage) -> Void)?

    /// キャンセル時のコールバック
    public var onCancel: (() -> Void)?

    public init() {}

    /// キャプチャ画像をインライン編集モードで表示
    /// - Parameters:
    ///   - image: キャプチャされた画像
    ///   - screenRect: 画面上の選択範囲（macOS 座標系、左下原点）
    public func show(image: CGImage, screenRect: CGRect) {
        dismiss()

        let doc = AnnotateDocument(image: image)
        self.document = doc

        // キャンバスウィンドウ（選択範囲にぴったり配置）
        let canvasView = AnnotateCanvasView(
            frame: NSRect(origin: .zero, size: NSSize(width: screenRect.width, height: screenRect.height))
        )
        canvasView.document = doc

        let canvasWindow = NSWindow(
            contentRect: NSRect(origin: screenRect.origin, size: screenRect.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        canvasWindow.level = .screenSaver
        canvasWindow.isOpaque = false
        canvasWindow.backgroundColor = .clear
        canvasWindow.hasShadow = true
        canvasWindow.contentView = canvasView
        canvasWindow.orderFrontRegardless()
        canvasWindow.makeKey()
        self.window = canvasWindow

        // ツールバーパネル（選択範囲の下に配置）
        let toolbarView = InlineToolbarView(
            document: doc,
            onUndo: { doc.undo(); canvasView.needsDisplay = true },
            onRedo: { doc.redo(); canvasView.needsDisplay = true },
            onSave: { [weak self] in self?.handleSave(canvasView: canvasView) },
            onCancel: { [weak self] in self?.handleCancel() },
            onDone: { [weak self] in self?.handleDone(canvasView: canvasView) }
        )

        let hostingView = NSHostingView(rootView: toolbarView)
        let toolbarSize = NSSize(width: max(screenRect.width, 500), height: 44)
        hostingView.setFrameSize(toolbarSize)

        let toolbarPanel = NSPanel(
            contentRect: NSRect(
                origin: NSPoint(
                    x: screenRect.origin.x + (screenRect.width - toolbarSize.width) / 2,
                    y: screenRect.origin.y - toolbarSize.height - 8
                ),
                size: toolbarSize
            ),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        toolbarPanel.level = .screenSaver
        toolbarPanel.isOpaque = false
        toolbarPanel.backgroundColor = .clear
        toolbarPanel.hasShadow = true
        toolbarPanel.contentView = hostingView
        toolbarPanel.titleVisibility = .hidden
        toolbarPanel.titlebarAppearsTransparent = true
        toolbarPanel.orderFrontRegardless()
        self.toolbarWindow = toolbarPanel

        // Escape キーでキャンセル
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.handleCancel()
                return nil
            }
            return event
        }

        Logger.capture.info("インラインアノテーション開始")
    }

    /// 全ウィンドウを閉じる
    public func dismiss() {
        window?.orderOut(nil)
        window = nil
        toolbarWindow?.orderOut(nil)
        toolbarWindow = nil
        document = nil
    }

    // MARK: - Actions

    private func handleDone(canvasView: AnnotateCanvasView) {
        guard let image = renderResult(canvasView: canvasView) else { return }
        // クリップボードにコピー
        ImageExporter.copyToClipboard(image)
        onComplete?(image)
        dismiss()
        Logger.capture.info("インラインアノテーション完了（コピー）")
    }

    private func handleSave(canvasView: AnnotateCanvasView) {
        guard let image = renderResult(canvasView: canvasView) else { return }
        onSave?(image)
        dismiss()
        Logger.capture.info("インラインアノテーション完了（保存）")
    }

    private func handleCancel() {
        onCancel?()
        dismiss()
        Logger.capture.info("インラインアノテーションキャンセル")
    }

    private func renderResult(canvasView: AnnotateCanvasView) -> CGImage? {
        guard let doc = document else { return nil }
        let width = doc.originalImage.width
        let height = doc.originalImage.height

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        let size = CGSize(width: width, height: height)
        ctx.draw(doc.originalImage, in: CGRect(origin: .zero, size: size))
        AnnotateRenderer.render(items: doc.items, in: ctx, size: size)
        return ctx.makeImage()
    }
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

    /// インライン編集で使うツール（Lark 準拠の並び）
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
