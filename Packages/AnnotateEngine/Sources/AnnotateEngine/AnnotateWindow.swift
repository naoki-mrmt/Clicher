import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities

/// Annotate エディタウィンドウを管理
@MainActor
public final class AnnotateWindow {
    private var window: NSWindow?

    /// エディタ完了時のコールバック（エクスポートされた画像）
    public var onComplete: ((CGImage) -> Void)?
    public var onError: ((String) -> Void)?

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

        // 画像サイズ（ポイント単位）に基づいてウィンドウサイズを計算（最大画面の80%）
        let displayScale = document.displayScale
        let imagePointSize = CGSize(
            width: CGFloat(result.image.width) / displayScale,
            height: CGFloat(result.image.height) / displayScale
        )
        let screenSize = ScreenUtilities.activeVisibleFrame.size
        let maxWidth = screenSize.width * 0.8
        let maxHeight = screenSize.height * 0.8

        let scale = min(maxWidth / imagePointSize.width, maxHeight / imagePointSize.height, 1.0)
        let toolPaletteWidth: CGFloat = 44
        let toolbarHeight: CGFloat = 44
        let windowSize = CGSize(
            width: max(imagePointSize.width * scale + toolPaletteWidth, 640),
            height: max(imagePointSize.height * scale + toolbarHeight, 480)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clicher — 編集"
        // self.window で保持しているため、close() 時の自動解放（over-release）を防ぐ
        window.isReleasedWhenClosed = false
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
        guard var image = renderDocument(document) else {
            Logger.capture.error("Annotate エクスポート失敗: renderDocument が nil")
            onError?(L10n.error)
            close()
            return
        }
        // 背景（Background Tool）を適用
        if document.isBackgroundEnabled {
            image = BackgroundTool.apply(to: image, config: document.backgroundConfig) ?? image
        }
        // ウォーターマーク挿入
        if let preset = defaultPreset {
            image = WatermarkRenderer.apply(to: image, preset: preset) ?? image
        }
        onComplete?(image)
        close()
    }

    /// ドキュメントを画像にレンダリング
    /// アノテーション座標はキャンバスのポイント座標系のため、
    /// `document.displayScale` でピクセル座標へスケールして元画像と合成する
    func renderDocument(_ document: AnnotateDocument) -> CGImage? {
        let width = document.originalImage.width
        let height = document.originalImage.height
        let scale = document.displayScale

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // キャンバスと同じポイントサイズ（AnnotateCanvasRepresentable のレイアウトと一致）
        let canvasSize = CGSize(
            width: CGFloat(width) / scale,
            height: CGFloat(height) / scale
        )

        // ポイント座標 → ピクセル座標（Retina でもアノテーションが描いた位置・サイズに一致）
        ctx.scaleBy(x: scale, y: scale)

        // 座標系を flipped に（AnnotateCanvasView.isFlipped=true と同じ座標系）
        ctx.translateBy(x: 0, y: canvasSize.height)
        ctx.scaleBy(x: 1, y: -1)

        // 元画像（CGImage は左下原点前提なのでフリップ済み座標を一時的に戻す）
        ctx.saveGState()
        ctx.translateBy(x: 0, y: canvasSize.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(document.originalImage, in: CGRect(origin: .zero, size: canvasSize))
        ctx.restoreGState()

        // アノテーション（flipped ポイント座標系でそのまま描画 — キャンバスの draw(_:) と同じ）
        AnnotateRenderer.render(items: document.items, in: ctx, size: canvasSize, originalImage: document.originalImage)

        guard var image = ctx.makeImage() else { return nil }

        // クロップ（cropRect はポイント座標なのでピクセルへスケールして適用）
        if let cropRect = document.cropRect {
            let scaledCrop = CGRect(
                x: cropRect.origin.x * scale,
                y: cropRect.origin.y * scale,
                width: cropRect.width * scale,
                height: cropRect.height * scale
            )
            if let cropped = image.cropping(to: scaledCrop) {
                image = cropped
            }
        }

        Logger.capture.info("Annotate エクスポート完了: \(image.width)x\(image.height)")
        return image
    }
}
