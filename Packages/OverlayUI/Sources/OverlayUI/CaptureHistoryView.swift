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
                    Text("履歴を選択")
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
                        // サムネイル
                        if let thumbnail = store.loadThumbnail(for: entry) {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                                .frame(width: 40, height: 30)
                        }

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
                Text("\(entries.count) 件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("全削除") {
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
            // サムネイルプレビュー
            if let thumbnail = store.loadThumbnail(for: entry) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // メタデータ
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("モード", value: entry.mode)
                LabeledContent("サイズ", value: entry.sizeLabel)
                LabeledContent("日時", value: entry.formattedDate)
                if let path = entry.filePath {
                    LabeledContent("ファイル", value: URL(fileURLWithPath: path).lastPathComponent)
                }
            }
            .font(.caption)

            Spacer()

            // アクション
            HStack {
                if let path = entry.filePath {
                    Button("Finder で表示") {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                    .controlSize(.small)
                }

                Spacer()

                Button("削除") {
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
