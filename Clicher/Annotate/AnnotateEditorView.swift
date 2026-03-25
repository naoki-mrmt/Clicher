import SwiftUI

/// Annotate エディタの SwiftUI ラッパー
struct AnnotateEditorView: View {
    let document: AnnotateDocument
    var onExport: ((CGImage) -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // ツールバー
            toolbar

            Divider()

            HStack(spacing: 0) {
                // ツールパレット（左）
                toolPalette

                Divider()

                // キャンバス
                AnnotateCanvasRepresentable(document: document)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // ツールオプション: 色
            ColorPicker("", selection: strokeColorBinding)
                .labelsHidden()

            // 線の太さ
            HStack(spacing: 4) {
                Image(systemName: "lineweight")
                    .font(.caption)
                Slider(
                    value: Bindable(document).currentStyle.lineWidth,
                    in: 1...20,
                    step: 1
                )
                .frame(width: 80)
                Text("\(Int(document.currentStyle.lineWidth))")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 20)
            }

            // 塗りつぶしトグル
            Toggle("塗りつぶし", isOn: Bindable(document).currentStyle.isFilled)
                .toggleStyle(.checkbox)

            Spacer()

            // Undo / Redo
            Button {
                document.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!document.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button {
                document.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!document.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider()
                .frame(height: 20)

            // エクスポート
            Button {
                // AnnotateCanvasView の exportImage 経由でエクスポート
                // 実際のトリガーは NSViewRepresentable 側で処理
                onDismiss?()
            } label: {
                Label("完了", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tool Palette

    private var toolPalette: some View {
        VStack(spacing: 2) {
            ForEach(AnnotationToolType.allCases) { tool in
                Button {
                    document.currentTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    document.currentTool == tool
                        ? AnyShapeStyle(.tint.opacity(0.15))
                        : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .help(tool.label)
            }

            Spacer()
        }
        .padding(6)
        .frame(width: 44)
    }

    // MARK: - Helpers

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: document.currentStyle.strokeColor) },
            set: { document.currentStyle.strokeColor = NSColor($0) }
        )
    }
}

// MARK: - NSViewRepresentable

/// AnnotateCanvasView を SwiftUI にブリッジ
struct AnnotateCanvasRepresentable: NSViewRepresentable {
    let document: AnnotateDocument

    func makeNSView(context: Context) -> AnnotateCanvasView {
        let canvas = AnnotateCanvasView(
            frame: NSRect(
                origin: .zero,
                size: NSSize(
                    width: document.originalImage.width,
                    height: document.originalImage.height
                )
            )
        )
        canvas.document = document
        return canvas
    }

    func updateNSView(_ nsView: AnnotateCanvasView, context: Context) {
        nsView.document = document
        nsView.needsDisplay = true
    }
}

// MARK: - Preview Helper

private enum PreviewHelper {
    static func makeDummyImage() -> CGImage {
        let size = CGSize(width: 640, height: 480)
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ), let image = ({
            ctx.setFillColor(CGColor(gray: 0.9, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: size))
            return ctx.makeImage()
        }()) else {
            fatalError("Preview用ダミー画像の生成に失敗")
        }
        return image
    }
}

#Preview {
    AnnotateEditorView(document: AnnotateDocument(image: PreviewHelper.makeDummyImage()))
}
