import SwiftUI

/// メニューバーのドロップダウンメニュー
struct MenuBarView: View {
    let coordinator: CaptureCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Capture Area", systemImage: "rectangle.dashed") {
            coordinator.startAreaCapture()
            openCaptureOverlay()
        }
        .keyboardShortcut("4", modifiers: [.command, .shift])

        Button("Capture Window", systemImage: "macwindow") {
            coordinator.startWindowCapture()
            openCaptureOverlay()
        }
        .keyboardShortcut("5", modifiers: [.command, .shift])

        Button("Capture Fullscreen", systemImage: "rectangle.inset.filled") {
            Task {
                await coordinator.captureFullscreen()
            }
        }
        .keyboardShortcut("6", modifiers: [.command, .shift])

        Divider()

        SettingsLink {
            Text("Preferences…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Clicher") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func openCaptureOverlay() {
        // キャプチャオーバーレイウィンドウを表示
        CaptureOverlayWindowController.shared.show(coordinator: coordinator)
    }
}
