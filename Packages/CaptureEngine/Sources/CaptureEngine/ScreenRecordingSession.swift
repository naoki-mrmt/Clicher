import ScreenCaptureKit
import AVFoundation
import AppKit
import OSLog
import Observation
import SharedModels
import Utilities

/// 画面録画セッション
/// ScreenCaptureKit の SCStream で画面をキャプチャし、AVAssetWriter で MP4 に書き出す
@Observable
@MainActor
public final class ScreenRecordingSession {
    /// 録画中かどうか
    public private(set) var isRecording = false

    /// 録画時間（秒）
    public private(set) var duration: TimeInterval = 0

    /// マイク音声を録音するか
    public var capturesMicrophone = false

    /// システム音声を録音するか
    public var capturesSystemAudio = true

    /// 録画完了コールバック（MP4 ファイルの URL）
    public var onComplete: ((URL) -> Void)?

    /// 録画エラーコールバック
    public var onError: ((String) -> Void)?

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var durationTimer: Task<Void, Never>?
    /// 録画開始時刻（正確な経過時間計測用）
    private var startTime: Date?
    /// StreamOutputHandler の強参照を保持（SCStream は delegate を弱参照するため）
    private var streamOutputHandler: StreamOutputHandler?

    /// バックグラウンドスレッドからの書き込みを保護するロック
    private let writeLock = NSLock()
    /// ロック保護下の書き込み用入力（バックグラウンドスレッドから安全にアクセス）
    nonisolated(unsafe) private var lockedVideoInput: AVAssetWriterInput?
    nonisolated(unsafe) private var lockedAudioInput: AVAssetWriterInput?

    public init() {}


    /// 録画を開始
    /// - Parameters:
    ///   - display: 対象ディスプレイ（nil でメインディスプレイ）
    ///   - sourceRect: 録画範囲（nil でフルスクリーン、SCK 座標系）
    public func start(display: SCDisplay? = nil, sourceRect: CGRect? = nil) async throws {
        guard !isRecording else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let targetDisplay = display ?? content.displays.first else {
            Logger.capture.error("録画対象のディスプレイが見つかりません")
            throw RecordingError.noDisplay
        }

        // 出力先
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Clicher_Recording_\(Int(Date().timeIntervalSince1970)).mp4"
        let url = tempDir.appendingPathComponent(fileName)
        outputURL = url

        // AVAssetWriter セットアップ
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let scaleFactor = ScreenUtilities.activeScaleFactor
        let width = Int(CGFloat(targetDisplay.width) * scaleFactor)
        let height = Int(CGFloat(targetDisplay.height) * scaleFactor)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        writer.add(input)

        // 音声入力セットアップ
        if capturesSystemAudio || capturesMicrophone {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000,
            ]
            let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput.expectsMediaDataInRealTime = true
            writer.add(audioWriterInput)
            self.audioInput = audioWriterInput
        }

        writer.startWriting()

        // AVAssetWriter のエラーチェック
        if let error = writer.error {
            Logger.capture.error("AVAssetWriter 開始失敗: \(error)")
            throw RecordingError.writerFailed(error)
        }

        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.videoInput = input
        self.adaptor = pixelBufferAdaptor

        // ロック保護下の参照を設定（同期コンテキストで実行）
        setLockedInputs(video: input, audio: audioInput)

        // SCStream セットアップ
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        if let sourceRect {
            config.sourceRect = sourceRect
            config.width = Int(sourceRect.width * scaleFactor)
            config.height = Int(sourceRect.height * scaleFactor)
        } else {
            config.width = width
            config.height = height
        }
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30fps
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = capturesSystemAudio

        let outputHandler = StreamOutputHandler(session: self)
        self.streamOutputHandler = outputHandler
        let captureStream = SCStream(filter: filter, configuration: config, delegate: outputHandler)
        try captureStream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        if capturesSystemAudio {
            try captureStream.addStreamOutput(outputHandler, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        }

        try await captureStream.startCapture()

        self.stream = captureStream
        isRecording = true
        duration = 0
        startTime = Date()

        // 録画時間カウンター（UI 表示用）
        durationTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.duration += 1
            }
        }

        Logger.capture.info("画面録画を開始: \(width)x\(height) @ 30fps")
    }

    /// 録画を停止
    public func stop() async {
        guard isRecording else { return }
        isRecording = false
        let elapsed = -(startTime?.timeIntervalSinceNow ?? 0)
        durationTimer?.cancel()
        durationTimer = nil
        startTime = nil

        // バックグラウンドスレッドからの書き込みを停止（stream 停止前に）
        setLockedInputs(video: nil, audio: nil)

        // SCStream 停止 & output 解除
        if let stream, let handler = streamOutputHandler {
            try? stream.removeStreamOutput(handler, type: .screen)
            if capturesSystemAudio {
                try? stream.removeStreamOutput(handler, type: .audio)
            }
            try? await stream.stopCapture()
        }
        stream = nil
        streamOutputHandler = nil

        // AVAssetWriter 完了
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        await assetWriter?.finishWriting()

        // finishWriting 後のエラーチェック
        if let writer = assetWriter, writer.status == .failed {
            let message = writer.error?.localizedDescription ?? "不明"
            Logger.capture.error("録画ファイルの書き込み失敗: \(message)")
            onError?(L10n.error)
            // 破損ファイルを削除
            if let url = outputURL {
                try? FileManager.default.removeItem(at: url)
            }
        } else if let url = outputURL {
            if elapsed < 0.5 {
                // 極短録画は無効として扱う
                Logger.capture.warning("録画時間が短すぎます: \(elapsed)秒")
                try? FileManager.default.removeItem(at: url)
            } else {
                onComplete?(url)
                Logger.capture.info("画面録画を停止: \(url.lastPathComponent) (\(Int(elapsed))秒)")
            }
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
        outputURL = nil
    }

    /// ロック保護下の入力参照を設定（@MainActor の同期コンテキストから呼ぶ）
    private nonisolated func setLockedInputs(video: AVAssetWriterInput?, audio: AVAssetWriterInput?) {
        writeLock.lock()
        lockedVideoInput = video
        lockedAudioInput = audio
        writeLock.unlock()
    }

    /// 映像サンプルバッファを受け取って書き込む（バックグラウンドスレッドから呼ばれる）
    nonisolated func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writeLock.lock()
        defer { writeLock.unlock() }
        guard let input = lockedVideoInput, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    /// 音声サンプルバッファを受け取って書き込む（バックグラウンドスレッドから呼ばれる）
    nonisolated func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writeLock.lock()
        defer { writeLock.unlock() }
        guard let input = lockedAudioInput, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }
}

// MARK: - Recording Errors

public enum RecordingError: Error, LocalizedError {
    case noDisplay
    case writerFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "録画対象のディスプレイが見つかりません"
        case .writerFailed(let error):
            return "録画の書き込みに失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - SCStreamOutput Handler

private final class StreamOutputHandler: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let session: ScreenRecordingSession

    init(session: ScreenRecordingSession) {
        self.session = session
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            session.handleVideoSampleBuffer(sampleBuffer)
        case .audio:
            session.handleAudioSampleBuffer(sampleBuffer)
        @unknown default:
            break
        }
    }
}
