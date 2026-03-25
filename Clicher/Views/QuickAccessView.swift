import SwiftUI

/// Quick Access Overlay の SwiftUI ビュー
struct QuickAccessView: View {
    let result: CaptureResult
    let onSave: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // サムネイル
            thumbnail
                .onHover { isHovering = $0 }

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
