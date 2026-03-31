import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities

/// Annotate エディタウィンドウを管理
@MainActor
public final class AnnotateWindow {
    private var window: NSWindow?
    private var canvasView: AnnotateCanvasView?

    /// エディタ完了時のコールバック（エクスポートされた画像）
    public var onComplete: ((CGImage) -> Void)?

    /// デフォルトブランドプリセット（設定されている場合、ツールの初期色に適用）
    public var defaultPreset: BrandPreset?

    public init() {}

    /// キャプチャ結果からエディタを開く
    public func open(with result: CaptureResult) {
        close()

        let document = AnnotateDocument(image: result.image)

        // デフォルトプリセットがあればアノテーションの初期色に適用
        if let preset = defaultPreset {
            document.currentStyle.strokeColor = NSColor(
                red: preset.primaryColor.red,
                green: preset.primaryColor.green,
                blue: preset.primaryColor.blue,
                alpha: preset.primaryColor.alpha
            )
        }

        var editorView = AnnotateEditorView(document: document)
        editorView.onDismiss = { [weak self] in
            self?.exportAndClose(document: document)
        }

        let hostingView = NSHostingView(rootView: editorView)

        // 画像サイズに基づいてウィンドウサイズを計算（最大画面の80%）
        let imageSize = CGSize(
            width: result.image.width,
            height: result.image.height
        )
        let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        let maxWidth = screenSize.width * 0.8
        let maxHeight = screenSize.height * 0.8

        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1.0)
        let windowSize = CGSize(
            width: max(imageSize.width * scale + 44, 640), // +44 for tool palette
            height: max(imageSize.height * scale + 44, 480) // +44 for toolbar
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clicher — 編集"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window

        Logger.app.info("Annotate エディタを開きました")
    }

    /// ウィンドウを閉じる
    public func close() {
        window?.close()
        window = nil
    }

    private func exportAndClose(document: AnnotateDocument) {
        var image = renderDocument(document)
        // ウォーターマーク挿入
        if let preset = defaultPreset, let img = image {
            image = WatermarkRenderer.apply(to: img, preset: preset)
        }
        if let image {
            onComplete?(image)
        }
        close()
    }

    /// ドキュメントを画像にレンダリング
    private func renderDocument(_ document: AnnotateDocument) -> CGImage? {
        let width = document.originalImage.width
        let height = document.originalImage.height

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        let size = CGSize(width: width, height: height)

        // 座標系を flipped に（AnnotateCanvasView.isFlipped=true と同じ座標系）
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        // 元画像（CGImage は左下原点前提なのでフリップ済み座標を一時的に戻す）
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(document.originalImage, in: CGRect(origin: .zero, size: size))
        ctx.restoreGState()

        // アノテーション（flipped 座標系でそのまま描画）
        AnnotateRenderer.render(items: document.items, in: ctx, size: size, originalImage: document.originalImage)

        guard var image = ctx.makeImage() else { return nil }

        // クロップ（cropRect は flipped 座標系 = makeImage() のピクセル配列と一致）
        if let cropRect = document.cropRect {
            if let cropped = image.cropping(to: cropRect) {
                image = cropped
            }
        }

        Logger.capture.info("Annotate エクスポート完了: \(width)x\(height)")
        return image
    }
}
