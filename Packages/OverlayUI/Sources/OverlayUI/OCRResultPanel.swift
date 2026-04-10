import AppKit
import SwiftUI
import SharedModels

/// OCR 結果を画面中央に表示するパネル（Lark 風）
/// テキスト全文を表示し、選択・コピーが可能
@MainActor
public final class OCRResultPanel {
    private var panel: NSPanel?

    public init() {}

    /// OCR 結果パネルを表示
    /// - Parameters:
    ///   - text: 認識されたテキスト
    ///   - onCopyAll: 全文コピー時のコールバック
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

        // 画面中央に配置
        p.center()
        p.orderFrontRegardless()

        // ESC で閉じる
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }

        self.panel = p
    }

    /// パネルを閉じる
    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - OCR Result View

struct OCRResultView: View {
    let text: String
    let onCopyAll: () -> Void
    let onClose: () -> Void

    @State private var showCopiedToast = false

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
                SelectableText(text: text)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)

            Divider()

            // アクションバー
            HStack {
                // テキスト文字数
                Text("\(text.count) " + (L10n.isEnglishPublic ? "characters" : "文字"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                // コピーボタン
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

// MARK: - Selectable Text (NSTextView wrapper)

/// NSTextView をラップして、テキストの選択・コピーを可能にする
struct SelectableText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.string = text
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            textView.string = text
        }
    }
}
