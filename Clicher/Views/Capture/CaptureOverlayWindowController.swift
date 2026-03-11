import AppKit
import SwiftUI

/// キャプチャ用の透明オーバーレイウィンドウを管理
final class CaptureOverlayWindowController {
    static let shared = CaptureOverlayWindowController()
    private var overlayWindows: [NSWindow] = []

    private init() {}

    /// オーバーレイウィンドウを表示
    func show(coordinator: CaptureCoordinator) {
        dismiss()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true

            if coordinator.isSelectingArea {
                let hostingView = NSHostingView(
                    rootView: AreaSelectionView(coordinator: coordinator, onDismiss: { [weak self] in
                        self?.dismiss()
                    })
                )
                window.contentView = hostingView
            } else if coordinator.isSelectingWindow {
                let hostingView = NSHostingView(
                    rootView: WindowSelectionView(coordinator: coordinator, onDismiss: { [weak self] in
                        self?.dismiss()
                    })
                )
                window.contentView = hostingView
            }

            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
    }

    /// オーバーレイウィンドウを閉じる
    func dismiss() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
