import AppKit
import SwiftUI
import OSLog
import SharedModels
import Utilities

/// キャプチャ画像のプレビューウィンドウ
/// サムネイルクリックで拡大表示、ドラッグ&ドロップで外部アプリに共有
@MainActor
public final class PreviewWindow: NSObject, NSWindowDelegate {
    private static var activeWindow: NSWindow?
    private static let delegate = PreviewWindow()

    /// プレビューウィンドウを表示
    public static func show(image: NSImage) {
        activeWindow?.close()
        activeWindow = nil

        let maxSize = CGSize(width: 800, height: 600)
        let imageSize = image.size
        let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height, 1.0)
        let displaySize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        let view = PreviewView(image: image)
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(displaySize)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: displaySize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.preview
        window.contentView = hostingView
        window.center()
        window.delegate = delegate

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        activeWindow = window
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        PreviewWindow.activeWindow = nil
    }
}

// MARK: - Preview View

struct PreviewView: View {
    let image: NSImage
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
        }
        .background(.black)
        .draggable(Image(nsImage: image))
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = scale > 1.0 ? 1.0 : 2.0
                baseScale = scale
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = max(0.5, min(5.0, baseScale * value.magnification))
                }
                .onEnded { value in
                    baseScale = max(0.5, min(5.0, baseScale * value.magnification))
                    scale = baseScale
                }
        )
    }
}
