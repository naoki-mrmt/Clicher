import AppKit
import SwiftUI

/// Quick Access Overlay のウィンドウ管理
final class OverlayWindowController {
    static let shared = OverlayWindowController()
    private var panel: NSPanel?
    private var autoCloseTask: Task<Void, Never>?

    private init() {}

    /// Overlay を表示
    func show(
        captureResult: CaptureResult,
        coordinator: CaptureCoordinator,
        position: OverlayPosition = .bottomRight,
        autoCloseDelay: TimeInterval = 5.0
    ) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(
            rootView: QuickAccessOverlayView(
                captureResult: captureResult,
                coordinator: coordinator
            )
        )
        panel.contentView = hostingView

        // 位置を計算
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 20
        let panelSize = panel.frame.size

        var origin: CGPoint
        switch position {
        case .topLeft:
            origin = CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - panelSize.height - padding
            )
        case .topRight:
            origin = CGPoint(
                x: screenFrame.maxX - panelSize.width - padding,
                y: screenFrame.maxY - panelSize.height - padding
            )
        case .bottomLeft:
            origin = CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
        case .bottomRight:
            origin = CGPoint(
                x: screenFrame.maxX - panelSize.width - padding,
                y: screenFrame.minY + padding
            )
        }

        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // 自動クローズ
        autoCloseTask?.cancel()
        autoCloseTask = Task {
            try? await Task.sleep(for: .seconds(autoCloseDelay))
            if !Task.isCancelled {
                dismiss()
                coordinator.dismissOverlay()
            }
        }
    }

    /// Overlay を閉じる
    func dismiss() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
