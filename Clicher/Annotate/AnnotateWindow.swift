import AppKit
import SwiftUI
import OSLog

/// Annotate エディタウィンドウを管理
final class AnnotateWindow {
    private var window: NSWindow?
    private var canvasView: AnnotateCanvasView?

    /// エディタ完了時のコールバック（エクスポートされた画像）
    var onComplete: ((CGImage) -> Void)?

    /// キャプチャ結果からエディタを開く
    func open(with result: CaptureResult) {
        close()

        let document = AnnotateDocument(image: result.image)

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
    func close() {
        window?.close()
        window = nil
    }

    private func exportAndClose(document: AnnotateDocument) {
        // NSHostingView 内の AnnotateCanvasView からエクスポート
        // 簡易実装: ドキュメントから直接レンダリング
        let image = renderDocument(document)
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

        // 元画像
        ctx.draw(document.originalImage, in: CGRect(origin: .zero, size: size))

        // アノテーション
        AnnotateRenderer.render(items: document.items, in: ctx, size: size)

        guard var image = ctx.makeImage() else { return nil }

        // クロップ
        if let cropRect = document.cropRect {
            if let cropped = image.cropping(to: cropRect) {
                image = cropped
            }
        }

        Logger.capture.info("Annotate エクスポート完了: \(width)x\(height)")
        return image
    }
}
