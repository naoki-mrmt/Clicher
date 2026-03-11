//
//  ClicherApp.swift
//  Clicher
//
//  Created by FONXHOUND on 2026/03/11.
//

import SwiftUI

@main
struct ClicherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = CaptureCoordinator()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // メニューバーアプリ（Dockアイコンなし）
        MenuBarExtra("Clicher", systemImage: "camera.viewfinder") {
            MenuBarView(coordinator: coordinator)
                .task {
                    connectHotkeys()
                    await coordinator.permissionManager.checkAllPermissions()
                }
                .onChange(of: coordinator.showAnnotateEditor) {
                    if coordinator.showAnnotateEditor {
                        openWindow(id: "annotate")
                    }
                }
        }

        // 設定ウィンドウ
        Settings {
            SettingsView(settings: coordinator.settings)
        }

        // Annotateエディタウィンドウ
        Window("Annotate", id: "annotate") {
            if let result = coordinator.lastCaptureResult {
                AnnotateEditorView(
                    captureResult: result,
                    settings: coordinator.settings,
                    onDismiss: { coordinator.dismissAnnotateEditor() }
                )
            }
        }
        .defaultSize(width: 900, height: 700)
    }

    // MARK: - Hotkey → Coordinator Bridge

    private func connectHotkeys() {
        appDelegate.onAreaCapture = { [coordinator] in
            coordinator.startAreaCapture()
            CaptureOverlayWindowController.shared.show(coordinator: coordinator)
        }
        appDelegate.onWindowCapture = { [coordinator] in
            coordinator.startWindowCapture()
            CaptureOverlayWindowController.shared.show(coordinator: coordinator)
        }
        appDelegate.onFullscreenCapture = { [coordinator] in
            Task {
                await coordinator.captureFullscreen()
            }
        }
    }
}
