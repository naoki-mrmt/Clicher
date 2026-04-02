import SwiftUI
import SharedModels
import Utilities

/// キャプチャ履歴ビューア
public struct CaptureHistoryView: View {
    let store: CaptureHistoryStore

    @State private var entries: [CaptureHistoryEntry] = []
    @State private var selectedEntry: CaptureHistoryEntry?

    public init(store: CaptureHistoryStore) {
        self.store = store
    }

    public var body: some View {
        HSplitView {
            // 一覧（左）
            historyList
                .frame(minWidth: 200, maxWidth: 260)

            // プレビュー（右）
            if let entry = selectedEntry {
                previewPanel(entry)
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text(L10n.selectHistory)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear { entries = store.allEntries() }
    }

    // MARK: - History List

    private var historyList: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { selectedEntry?.id },
                set: { id in selectedEntry = entries.first { $0.id == id } }
            )) {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        // サムネイル（非同期読み込み）
                        AsyncThumbnailView(store: store, entry: entry)
                            .frame(width: 40, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.mode)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(entry.formattedDate)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(entry.id)
                }
            }

            Divider()

            HStack {
                Text(L10n.itemCount(entries.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.clearAll) {
                    store.clearAll()
                    entries = store.allEntries()
                    selectedEntry = nil
                }
                .font(.caption)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
            }
            .padding(6)
        }
    }

    // MARK: - Preview

    private func previewPanel(_ entry: CaptureHistoryEntry) -> some View {
        VStack(spacing: 12) {
            // サムネイルプレビュー（非同期読み込み）
            AsyncThumbnailView(store: store, entry: entry)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // メタデータ
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent(L10n.mode, value: entry.mode)
                LabeledContent(L10n.size, value: entry.sizeLabel)
                LabeledContent(L10n.dateTime, value: entry.formattedDate)
                if let path = entry.filePath {
                    LabeledContent(L10n.file, value: URL(fileURLWithPath: path).lastPathComponent)
                }
            }
            .font(.caption)

            Spacer()

            // アクション
            HStack {
                if let path = entry.filePath {
                    Button(L10n.showInFinder) {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                    .controlSize(.small)
                }

                Spacer()

                Button(L10n.delete) {
                    store.delete(entry)
                    entries = store.allEntries()
                    selectedEntry = nil
                }
                .controlSize(.small)
                .foregroundStyle(.red)
            }
        }
        .padding()
    }
}

// MARK: - Async Thumbnail

private struct AsyncThumbnailView: View {
    let store: CaptureHistoryStore
    let entry: CaptureHistoryEntry
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
            }
        }
        .task {
            image = store.loadThumbnail(for: entry)
        }
    }
}
