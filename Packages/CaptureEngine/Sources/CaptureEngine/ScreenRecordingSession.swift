import ScreenCaptureKit
import AVFoundation
import AppKit
import OSLog
import Observation
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

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var startTime: CMTime?
    private var durationTimer: Task<Void, Never>?

    public init() {}

    /// 録画を開始
    public func start(display: SCDisplay? = nil) async throws {
        guard !isRecording else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let targetDisplay = display ?? content.displays.first else {
            Logger.capture.error("録画対象のディスプレイが見つかりません")
            return
        }

        // 出力先
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Clicher_Recording_\(Int(Date().timeIntervalSince1970)).mp4"
        let url = tempDir.appendingPathComponent(fileName)
        outputURL = url

        // AVAssetWriter セットアップ
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
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
            self.unsafeAudioInput = audioWriterInput
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.videoInput = input
        self.unsafeVideoInput = input
        self.adaptor = pixelBufferAdaptor

        // SCStream セットアップ
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30fps
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = capturesSystemAudio

        let streamDelegate = StreamOutputHandler(session: self)
        let captureStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try captureStream.addStreamOutput(streamDelegate, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        if capturesSystemAudio {
            try captureStream.addStreamOutput(streamDelegate, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        }

        try await captureStream.startCapture()

        self.stream = captureStream
        isRecording = true
        duration = 0

        // 録画時間カウンター
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
        durationTimer?.cancel()
        durationTimer = nil

        // SCStream 停止
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil

        // AVAssetWriter 完了
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        await assetWriter?.finishWriting()

        if let url = outputURL {
            onComplete?(url)
            Logger.capture.info("画面録画を停止: \(url.lastPathComponent) (\(Int(self.duration))秒)")
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
        unsafeVideoInput = nil
        unsafeAudioInput = nil
        adaptor = nil
        startTime = nil
    }

    /// 映像サンプルバッファを受け取って書き込む
    nonisolated func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        nonisolated(unsafe) let input = unsafeVideoInput
        guard let input, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    /// 音声サンプルバッファを受け取って書き込む
    nonisolated func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        nonisolated(unsafe) let input = unsafeAudioInput
        guard let input, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    /// nonisolated アクセス用の内部ストレージ
    nonisolated(unsafe) private var unsafeVideoInput: AVAssetWriterInput?
    nonisolated(unsafe) private var unsafeAudioInput: AVAssetWriterInput?
}

// MARK: - SCStreamOutput Handler

private final class StreamOutputHandler: NSObject, SCStreamOutput, @unchecked Sendable {
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
