import AppKit
import SwiftUI
import SharedModels

/// OCR 結果を画面中央に表示するパネル（Lark 風）
/// テキスト全文を表示し、選択・コピーが可能
@MainActor
public final class OCRResultPanel {
    private var panel: NSPanel?
    private var keyMonitor: Any?

    public init() {}

    /// OCR 結果パネルを表示
    public func show(text: String, onCopyAll: @escaping () -> Void) {
        dismiss()

        let view = OCRResultView(
            text: text,
            onCopyAll: { [weak self] in
                onCopyAll()
                self?.dismiss()
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize
        let panelSize = NSSize(
            width: min(max(fittingSize.width, 320), 560),
            height: min(max(fittingSize.height, 200), 480)
        )
        hostingView.setFrameSize(panelSize)

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .closable],
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

        // ESC で閉じる
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }

        self.panel = p
    }

    /// パネルを閉じる
    public func dismiss() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - OCR Result View

struct OCRResultView: View {
    let text: String
    let onCopyAll: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(.secondary)
                Text(L10n.recognizedText)
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
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider()

            // テキスト表示（選択・コピー可能）
            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxHeight: 320)

            Divider()

            // アクションバー
            HStack {
                Text("\(text.count) " + (L10n.isEnglishPublic ? "characters" : "文字"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    onCopyAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text(L10n.copyAll)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 480)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}
