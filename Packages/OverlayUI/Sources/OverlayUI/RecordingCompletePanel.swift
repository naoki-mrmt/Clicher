import AppKit
import SwiftUI
import SharedModels
import Utilities

/// 録画完了後に保存先・コピーを選択するパネル
@MainActor
public final class RecordingCompletePanel {
    private var panel: NSPanel?
    private var keyMonitor: Any?

    /// ローカルに保存
    public var onSave: ((URL) -> Void)?
    /// Finder で表示
    public var onReveal: ((URL) -> Void)?
    /// クリップボードにコピー（ファイルパスとして）
    public var onCopy: ((URL) -> Void)?
    /// GIF に変換
    public var onConvertGIF: ((URL) -> Void)?
    /// 閉じる
    public var onClose: (() -> Void)?

    public init() {}

    /// パネルを表示
    public func show(videoURL: URL) {
        dismiss()

        let view = RecordingCompleteView(
            fileName: videoURL.lastPathComponent,
            onSave: { [weak self] in
                self?.onSave?(videoURL)
                self?.dismiss()
            },
            onReveal: { [weak self] in
                self?.onReveal?(videoURL)
                self?.dismiss()
            },
            onCopy: { [weak self] in
                self?.onCopy?(videoURL)
                self?.dismiss()
            },
            onConvertGIF: { [weak self] in
                self?.onConvertGIF?(videoURL)
                self?.dismiss()
            },
            onClose: { [weak self] in
                self?.onClose?()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize
        hostingView.setFrameSize(fittingSize)

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.contentView = hostingView
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true

        p.center()
        p.orderFrontRegardless()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onClose?()
                self?.dismiss()
                return nil
            }
            return event
        }

        self.panel = p
    }

    public func dismiss() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - SwiftUI View

struct RecordingCompleteView: View {
    let fileName: String
    let onSave: () -> Void
    let onReveal: () -> Void
    let onCopy: () -> Void
    let onConvertGIF: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // ヘッダー
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(L10n.recordingComplete)
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // ファイル名
            HStack(spacing: 6) {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            // アクションボタン
            HStack(spacing: 8) {
                actionButton(icon: "folder", label: L10n.save, color: .blue) {
                    onSave()
                }
                actionButton(icon: "doc.on.doc", label: L10n.copy, color: .secondary) {
                    onCopy()
                }
                actionButton(icon: "gift", label: "GIF", color: .orange) {
                    onConvertGIF()
                }
                actionButton(icon: "magnifyingglass", label: L10n.revealInFinder, color: .secondary) {
                    onReveal()
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
