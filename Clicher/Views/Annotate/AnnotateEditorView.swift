import SwiftUI
import UniformTypeIdentifiers

/// Annotateエディタのメインビュー
struct AnnotateEditorView: View {
    let captureResult: CaptureResult
    let settings: AppSettings
    let onDismiss: () -> Void

    @State private var document: AnnotateDocument
    @State private var zoomScale: CGFloat = 1.0

    init(captureResult: CaptureResult, settings: AppSettings, onDismiss: @escaping () -> Void) {
        self.captureResult = captureResult
        self.settings = settings
        self.onDismiss = onDismiss
        self._document = State(initialValue: AnnotateDocument(image: captureResult.image))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ツールオプションバー
            AnnotateOptionsBar(document: document)

            // メインコンテンツ
            HStack(spacing: 0) {
                // ツールバー（左側）
                AnnotateToolbarView(document: document)
                    .padding(8)

                // キャンバス
                ScrollView([.horizontal, .vertical]) {
                    AnnotateCanvasView(document: document)
                        .frame(
                            width: CGFloat(captureResult.image.width) / 2 * zoomScale,
                            height: CGFloat(captureResult.image.height) / 2 * zoomScale
                        )
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }

            // ボトムバー
            HStack {
                // ズームコントロール
                HStack(spacing: 8) {
                    Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                        zoomScale = max(0.25, zoomScale - 0.25)
                    }
                    .labelStyle(.iconOnly)

                    Text(zoomScale, format: .percent)
                        .font(.caption)
                        .frame(width: 50)

                    Button("Zoom In", systemImage: "plus.magnifyingglass") {
                        zoomScale = min(4.0, zoomScale + 0.25)
                    }
                    .labelStyle(.iconOnly)
                }

                Spacer()

                // エクスポートボタン
                Button("Copy", systemImage: "doc.on.doc") {
                    exportToClipboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Save", systemImage: "square.and.arrow.down") {
                    exportToFile()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Done", systemImage: "checkmark") {
                    onDismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Export

    private func exportToClipboard() {
        guard let finalImage = document.renderFinalImage() else { return }
        let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: finalImage.width, height: finalImage.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }

    private func exportToFile() {
        guard let finalImage = document.renderFinalImage() else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = settings.fileNamePattern.generateName()
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            let nsImage = NSImage(
                cgImage: finalImage,
                size: NSSize(width: finalImage.width, height: finalImage.height)
            )
            let format: NSBitmapImageRep.FileType = url.pathExtension == "jpg" ? .jpeg : .png
            if let tiffData = nsImage.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiffData),
               let data = rep.representation(using: format, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }
}
