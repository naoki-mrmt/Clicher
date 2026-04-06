import Vision
import CoreGraphics
import AppKit
import OSLog
import Utilities

/// OCR テキスト認識結果
public struct OCRResult: Sendable {
    /// 認識されたテキスト
    public let text: String

    /// 検出されたバーコード/QRコードの値
    public let barcodes: [String]

    /// 結果が空かどうか
    public var isEmpty: Bool {
        text.isEmpty && barcodes.isEmpty
    }

    public init(text: String, barcodes: [String] = []) {
        self.text = text
        self.barcodes = barcodes
    }
}

/// Vision フレームワークを使った OCR サービス
public enum OCRService {
    /// 画像からテキストを認識（バックグラウンドスレッドで実行）
    public static func recognizeText(
        from image: CGImage,
        languages: [String] = ["ja", "en"]
    ) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            let barcodes = try Self.detectBarcodesSync(from: image)

            Logger.capture.info("OCR 完了: \(observations.count) 行検出")
            return OCRResult(text: text, barcodes: barcodes)
        }.value
    }

    /// 画像からバーコード/QRコードを検出（同期版、内部用）
    private static func detectBarcodesSync(from image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let values = observations.compactMap { $0.payloadStringValue }

        if !values.isEmpty {
            Logger.capture.info("バーコード検出: \(values.count) 個")
        }
        return values
    }

    /// 画像からバーコード/QRコードを検出
    public static func detectBarcodes(from image: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try Self.detectBarcodesSync(from: image)
        }.value
    }

    /// OCR + バーコード検出を実行し、結果をクリップボードにコピー
    /// - Parameter onError: エラー時のコールバック（UI通知用）
    public static func performOCRAndCopy(
        from image: CGImage,
        onError: (@Sendable (String) -> Void)? = nil
    ) async {
        do {
            let result = try await recognizeText(from: image)
            if !result.isEmpty {
                let fullText: String
                if result.barcodes.isEmpty {
                    fullText = result.text
                } else {
                    let barcodeSection = result.barcodes.joined(separator: "\n")
                    fullText = result.text.isEmpty
                        ? barcodeSection
                        : "\(result.text)\n\n--- Barcodes ---\n\(barcodeSection)"
                }
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(fullText, forType: .string)
                }
                Logger.capture.info("OCR 結果をクリップボードにコピーしました")
            } else {
                Logger.capture.info("OCR 結果が空です")
                onError?("テキストが検出されませんでした")
            }
        } catch {
            Logger.capture.error("OCR 失敗: \(error)")
            onError?("OCR 失敗: \(error.localizedDescription)")
        }
    }
}
