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
        case high, medium, low, hd720, hd1080

        var label: String {
            switch self {
            case .high: L10n.qualityHigh
            case .medium: L10n.qualityMedium
            case .low: L10n.qualityLow
            case .hd720: "720p"
            case .hd1080: "1080p"
            }
        }

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
                Text(L10n.videoEditor)
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
                    Text(L10n.trim)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text(L10n.trimStart)
                            .font(.caption)
                        Slider(value: $trimStart, in: 0...info.duration)
                        Text(formatTime(trimStart))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 50)
                    }

                    HStack {
                        Text(L10n.trimEnd)
                            .font(.caption)
                        Slider(value: $trimEnd, in: 0...info.duration)
                        Text(formatTime(trimEnd))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 50)
                    }

                    Text(L10n.selectedRange(formatTime(max(0, trimEnd - trimStart))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 品質設定
                Picker(L10n.quality, selection: $selectedQuality) {
                    ForEach(QualityOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                // 動画情報
                HStack(spacing: 16) {
                    Label("\(Int(info.size.width))×\(Int(info.size.height))", systemImage: "rectangle")
                    Label("\(Int(info.fps))fps", systemImage: "film")
                    Label(info.hasAudio ? L10n.hasAudio : L10n.noAudio, systemImage: info.hasAudio ? "speaker.wave.2" : "speaker.slash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ProgressView(L10n.loading)
            }

            Spacer()

            // アクション
            HStack {
                Button(L10n.cancel) { onDismiss?() }
                Spacer()

                Button(L10n.convertToGIF) {
                    exportAsGIF()
                }
                .disabled(isExporting)

                Button(L10n.exportAction) {
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
