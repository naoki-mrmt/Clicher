import SwiftUI

/// キャプチャ後に表示されるQuick Access Overlay
struct QuickAccessOverlayView: View {
    let captureResult: CaptureResult
    let coordinator: CaptureCoordinator
    @Environment(\.openWindow) private var openWindow

    @State private var isHovering = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // サムネイル
            Image(nsImage: captureResult.nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 180)
                .clipShape(.rect(cornerRadius: 8))
                .shadow(radius: 4)

            // アクションバー
            if isHovering {
                HStack(spacing: 12) {
                    OverlayActionButton(
                        title: "Copy",
                        icon: "doc.on.doc",
                        action: { coordinator.copyToClipboard() }
                    )
                    OverlayActionButton(
                        title: "Save",
                        icon: "square.and.arrow.down",
                        action: { coordinator.saveToFile() }
                    )
                    OverlayActionButton(
                        title: "Edit",
                        icon: "pencil.tip.crop.circle",
                        action: {
                            coordinator.openAnnotateEditor()
                            openWindow(id: "annotate")
                        }
                    )
                    OverlayActionButton(
                        title: "Close",
                        icon: "xmark",
                        action: { coordinator.dismissOverlay() }
                    )
                }
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // 上スワイプ → 保存
                    if value.translation.height < -50 {
                        coordinator.saveToFile()
                    }
                    // 下スワイプ → 閉じる
                    else if value.translation.height > 50 {
                        coordinator.dismissOverlay()
                    }
                    withAnimation {
                        dragOffset = .zero
                    }
                }
        )
        .draggable(captureResult.nsImage)
    }
}

/// Overlay のアクションボタン
struct OverlayActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: icon, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.title3)
            .frame(width: 32, height: 32)
            .contentShape(.rect)
            .help(title)
    }
}
