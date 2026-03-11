import SwiftUI

/// エリアキャプチャ用の範囲選択ビュー
struct AreaSelectionView: View {
    let coordinator: CaptureCoordinator
    let onDismiss: () -> Void

    @State private var selectionStart: CGPoint?
    @State private var selectionEnd: CGPoint?
    @State private var mousePosition: CGPoint = .zero
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明オーバーレイ
                Color.black.opacity(0.3)

                // 選択範囲のカットアウト
                if let rect = selectionRect {
                    Rectangle()
                        .path(in: rect)
                        .fill(.clear)
                        .background {
                            Rectangle()
                                .fill(.clear)
                                .frame(width: rect.width, height: rect.height)
                                .position(
                                    x: rect.midX,
                                    y: rect.midY
                                )
                        }

                    // 選択範囲の枠線
                    Rectangle()
                        .stroke(.white, lineWidth: 1)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    // サイズ表示
                    sizeLabel(for: rect)
                }

                // クロスヘア
                if !isDragging {
                    CrosshairView(position: mousePosition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mousePosition = location
                case .ended:
                    break
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDragging {
                            selectionStart = value.startLocation
                            isDragging = true
                        }
                        selectionEnd = value.location
                    }
                    .onEnded { _ in
                        isDragging = false
                        if let rect = selectionRect, rect.width > 5, rect.height > 5 {
                            onDismiss()
                            Task {
                                await coordinator.captureArea(rect: rect)
                            }
                        } else {
                            selectionStart = nil
                            selectionEnd = nil
                        }
                    }
            )
            .onKeyPress(.escape) {
                onDismiss()
                coordinator.isSelectingArea = false
                return .handled
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private var selectionRect: CGRect? {
        guard let start = selectionStart, let end = selectionEnd else { return nil }
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func sizeLabel(for rect: CGRect) -> some View {
        Text("\(Int(rect.width)) × \(Int(rect.height))")
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7))
            .foregroundStyle(.white)
            .clipShape(.rect(cornerRadius: 4))
            .position(x: rect.midX, y: rect.maxY + 20)
    }
}

/// クロスヘア表示
struct CrosshairView: View {
    let position: CGPoint

    var body: some View {
        ZStack {
            // 水平線
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: 1)
                .position(x: position.x, y: position.y)

            // 垂直線
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(maxWidth: 1, maxHeight: .infinity)
                .position(x: position.x, y: position.y)

            // 座標表示
            Text("\(Int(position.x)), \(Int(position.y))")
                .font(.system(.caption2, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.7))
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 3))
                .position(x: position.x + 50, y: position.y - 20)
        }
        .allowsHitTesting(false)
    }
}
