import SwiftUI
import SharedModels

/// Annotate エディタの SwiftUI ラッパー
public struct AnnotateEditorView: View {
    public let document: AnnotateDocument
    public var onExport: ((CGImage) -> Void)?
    public var onDismiss: (() -> Void)?

    @State private var backgroundConfig = BackgroundConfig()
    @State private var isBackgroundEnabled = false

    public init(
        document: AnnotateDocument,
        onExport: ((CGImage) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.document = document
        self.onExport = onExport
        self.onDismiss = onDismiss
    }

    public var body: some View {
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

                // 背景設定パネル（右）
                if isBackgroundEnabled || document.currentTool == .crop {
                    Divider()
                    ScrollView {
                        BackgroundSettingsView(
                            config: $backgroundConfig,
                            isEnabled: $isBackgroundEnabled
                        )
                    }
                }
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

            // 背景設定トグル
            Toggle(isOn: $isBackgroundEnabled) {
                Image(systemName: "photo.artframe")
            }
            .toggleStyle(.button)
            .help("背景設定")

            Divider()
                .frame(height: 20)

            // エクスポート
            Button {
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
public struct AnnotateCanvasRepresentable: NSViewRepresentable {
    public let document: AnnotateDocument

    public init(document: AnnotateDocument) {
        self.document = document
    }

    public func makeNSView(context: Context) -> AnnotateCanvasView {
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

    public func updateNSView(_ nsView: AnnotateCanvasView, context: Context) {
        nsView.document = document
        nsView.needsDisplay = true
    }
}
