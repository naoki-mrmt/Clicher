import SwiftUI
import ScreenCaptureKit

/// ウィンドウキャプチャ用の選択ビュー
struct WindowSelectionView: View {
    let coordinator: CaptureCoordinator
    let onDismiss: () -> Void

    @State private var windows: [SCWindow] = []
    @State private var hoveredWindowID: CGWindowID?
    @State private var mousePosition: CGPoint = .zero

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // ホバー中のウィンドウをハイライト
            if let window = windows.first(where: { $0.windowID == hoveredWindowID }) {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 3)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(
                        width: window.frame.width,
                        height: window.frame.height
                    )
                    .position(
                        x: window.frame.midX,
                        y: window.frame.midY
                    )
            }

            // ウィンドウ選択のヒント
            VStack {
                Text("Click a window to capture")
                    .font(.title3)
                    .bold()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 10))
                Spacer()
            }
            .padding(.top, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                mousePosition = location
                updateHoveredWindow(at: location)
            case .ended:
                hoveredWindowID = nil
            }
        }
        .onTapGesture {
            if let window = windows.first(where: { $0.windowID == hoveredWindowID }) {
                onDismiss()
                Task {
                    await coordinator.captureWindow(window)
                }
            }
        }
        .onKeyPress(.escape) {
            onDismiss()
            coordinator.isSelectingWindow = false
            return .handled
        }
        .task {
            await loadWindows()
        }
    }

    // MARK: - Private

    private func loadWindows() async {
        do {
            let content = try await coordinator.captureService.availableContent()
            windows = content.windows.filter { window in
                window.isOnScreen && window.frame.width > 50 && window.frame.height > 50
            }
        } catch {
            // ウィンドウ一覧取得失敗
        }
    }

    private func updateHoveredWindow(at point: CGPoint) {
        // マウス位置に最も近いウィンドウを検出
        hoveredWindowID = windows.first { window in
            window.frame.contains(point)
        }?.windowID
    }
}
