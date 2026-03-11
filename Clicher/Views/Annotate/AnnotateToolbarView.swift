import SwiftUI

/// Annotateエディタのツールバー
struct AnnotateToolbarView: View {
    @Bindable var document: AnnotateDocument

    private let tools: [ToolType] = [
        .select, .arrow, .rectangle, .ellipse, .line,
        .text, .pixelate, .blur, .highlighter,
        .counter, .pencil, .crop, .spotlight,
    ]

    var body: some View {
        VStack(spacing: 4) {
            // ツール選択
            ForEach(tools) { tool in
                Button {
                    document.currentTool = tool
                } label: {
                    Image(systemName: tool.iconName)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(document.currentTool == tool ? Color.accentColor.opacity(0.2) : .clear)
                .clipShape(.rect(cornerRadius: 6))
                .help(tool.displayName)
            }

            Divider()
                .padding(.vertical, 4)

            // Undo / Redo
            Button("Undo", systemImage: "arrow.uturn.backward") {
                document.undo()
            }
            .labelStyle(.iconOnly)
            .disabled(!document.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button("Redo", systemImage: "arrow.uturn.forward") {
                document.redo()
            }
            .labelStyle(.iconOnly)
            .disabled(!document.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
    }
}

/// ツールオプションバー（上部に表示）
struct AnnotateOptionsBar: View {
    @Bindable var document: AnnotateDocument

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .black, .white,
    ]

    var body: some View {
        HStack(spacing: 16) {
            // カラーピッカー
            HStack(spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        document.currentStyle.strokeColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay {
                                if document.currentStyle.strokeColor == color {
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                ColorPicker("Custom", selection: $document.currentStyle.strokeColor)
                    .labelsHidden()
            }

            Divider()
                .frame(height: 24)

            // 線の太さ
            HStack(spacing: 4) {
                Text("Width:")
                    .font(.caption)
                Slider(
                    value: $document.currentStyle.strokeWidth,
                    in: 1...20,
                    step: 1
                )
                .frame(width: 100)
                Text(document.currentStyle.strokeWidth, format: .number.precision(.fractionLength(0)))
                    .font(.caption)
                    .frame(width: 24)
            }

            // 塗りつぶしトグル（矩形・楕円用）
            if [.rectangle, .ellipse].contains(document.currentTool) {
                Divider()
                    .frame(height: 24)
                Toggle("Fill", isOn: Binding(
                    get: { document.currentStyle.fillColor != .clear },
                    set: { filled in
                        document.currentStyle.fillColor = filled
                            ? document.currentStyle.strokeColor.opacity(0.3)
                            : .clear
                    }
                ))
                .toggleStyle(.checkbox)
            }

            // フォントサイズ（テキスト用）
            if document.currentTool == .text {
                Divider()
                    .frame(height: 24)
                HStack(spacing: 4) {
                    Text("Size:")
                        .font(.caption)
                    Slider(
                        value: $document.currentStyle.fontSize,
                        in: 10...72,
                        step: 2
                    )
                    .frame(width: 80)
                    Text(document.currentStyle.fontSize, format: .number.precision(.fractionLength(0)))
                        .font(.caption)
                        .frame(width: 24)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
