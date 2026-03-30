import SwiftUI
import AVFoundation
import OSLog
import SharedModels
import Utilities
import CaptureEngine

/// 簡易動画エディタビュー
public struct VideoEditorView: View {
    let videoURL: URL
    public var onExport: ((URL) -> Void)?
    public var onDismiss: (() -> Void)?

    @State private var info: VideoInfo?
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    @State private var selectedQuality: QualityOption = .high
    @State private var isExporting = false

    public init(videoURL: URL, onExport: ((URL) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.videoURL = videoURL
        self.onExport = onExport
        self.onDismiss = onDismiss
    }

    enum QualityOption: String, CaseIterable {
        case high = "高画質"
        case medium = "標準"
        case low = "低画質"
        case hd720 = "720p"
        case hd1080 = "1080p"

        var videoQuality: VideoQuality {
            switch self {
            case .high: .high
            case .medium: .medium
            case .low: .low
            case .hd720: .hd720
            case .hd1080: .hd1080
            }
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // ヘッダー
            HStack {
                Text("動画エディタ")
                    .font(.headline)
                Spacer()
                if let info {
                    Text(info.fileSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let info {
                // トリム設定
                VStack(alignment: .leading, spacing: 8) {
                    Text("トリム")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text("開始")
                            .font(.caption)
                        Slider(value: $trimStart, in: 0...info.duration)
                        Text(formatTime(trimStart))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 50)
                    }

                    HStack {
                        Text("終了")
                            .font(.caption)
                        Slider(value: $trimEnd, in: 0...info.duration)
                        Text(formatTime(trimEnd))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 50)
                    }

                    Text("選択範囲: \(formatTime(max(0, trimEnd - trimStart)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 品質設定
                Picker("品質", selection: $selectedQuality) {
                    ForEach(QualityOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                // 動画情報
                HStack(spacing: 16) {
                    Label("\(Int(info.size.width))×\(Int(info.size.height))", systemImage: "rectangle")
                    Label("\(Int(info.fps))fps", systemImage: "film")
                    Label(info.hasAudio ? "音声あり" : "音声なし", systemImage: info.hasAudio ? "speaker.wave.2" : "speaker.slash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ProgressView("読み込み中...")
            }

            Spacer()

            // アクション
            HStack {
                Button("キャンセル") { onDismiss?() }
                Spacer()

                Button("GIF に変換") {
                    exportAsGIF()
                }
                .disabled(isExporting)

                Button("エクスポート") {
                    exportTrimmed()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 480, height: 400)
        .task { await loadInfo() }
    }

    private func loadInfo() async {
        do {
            info = try await VideoEditor.getInfo(videoURL: videoURL)
            if let info {
                trimEnd = info.duration
            }
        } catch {
            Logger.capture.error("動画情報取得失敗: \(error)")
        }
    }

    private func exportTrimmed() {
        isExporting = true
        Task {
            do {
                let url = try await VideoEditor.trim(
                    videoURL: videoURL,
                    startTime: trimStart,
                    endTime: trimEnd
                )
                let finalURL = try await VideoEditor.changeQuality(
                    videoURL: url,
                    quality: selectedQuality.videoQuality
                )
                onExport?(finalURL)
            } catch {
                Logger.capture.error("動画エクスポート失敗: \(error)")
            }
            isExporting = false
        }
    }

    private func exportAsGIF() {
        isExporting = true
        Task {
            do {
                let gifURL = try await GIFConverter.convert(videoURL: videoURL, fps: 10, width: 480)
                onExport?(gifURL)
            } catch {
                Logger.capture.error("GIF 変換失敗: \(error)")
            }
            isExporting = false
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
