import AppKit
import SwiftUI
import OSLog
import Utilities

/// キャプチャ画像のプレビューウィンドウ
/// サムネイルクリックで拡大表示、ドラッグ&ドロップで外部アプリに共有
@MainActor
public final class PreviewWindow {
    private static var activeWindow: NSWindow?

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
        window.title = "プレビュー"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        activeWindow = window
    }
}

// MARK: - Preview View

struct PreviewView: View {
    let image: NSImage
    @State private var scale: CGFloat = 1.0

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
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = max(0.5, min(5.0, value.magnification))
                }
        )
    }
}
