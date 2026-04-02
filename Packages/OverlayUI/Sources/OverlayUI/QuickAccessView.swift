import SwiftUI
import SharedModels

/// Quick Access Overlay の SwiftUI ビュー
public struct QuickAccessView: View {
    public let result: CaptureResult
    public let onSave: () -> Void
    public let onCopy: () -> Void
    public let onEdit: () -> Void
    public let onPin: () -> Void
    public let onClose: () -> Void
    public let onHoverChanged: ((Bool) -> Void)?

    @State private var isHovering = false
    @State private var showPreview = false

    public init(
        result: CaptureResult,
        onSave: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onPin: @escaping () -> Void = {},
        onClose: @escaping () -> Void,
        onHoverChanged: ((Bool) -> Void)? = nil
    ) {
        self.result = result
        self.onSave = onSave
        self.onCopy = onCopy
        self.onEdit = onEdit
        self.onPin = onPin
        self.onClose = onClose
        self.onHoverChanged = onHoverChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            // サムネイル
            thumbnail
                .onHover {
                    isHovering = $0
                    onHoverChanged?($0)
                }

            // OCR テキストプレビュー
            if let ocrText = result.ocrText {
                ocrPreview(text: ocrText)
            }

            // アクションバー
            if isHovering {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 240)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .draggable(Image(nsImage: result.nsImage))
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: result.nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 240, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    showPreview = true
                    PreviewWindow.show(image: result.nsImage)
                }
                .help("クリックでプレビュー拡大")

            // 閉じるボタン
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(4)
            .opacity(isHovering ? 1 : 0)
        }
    }

    // MARK: - OCR Preview

    private func ocrPreview(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("認識テキスト")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(text)
                .font(.caption)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.3))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            actionButton(title: "保存", systemImage: "square.and.arrow.down") {
                onSave()
            }

            actionButton(title: "コピー", systemImage: "doc.on.doc") {
                onCopy()
            }

            actionButton(title: "編集", systemImage: "pencil") {
                onEdit()
            }

            actionButton(title: "ピン留め", systemImage: "pin") {
                onPin()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
