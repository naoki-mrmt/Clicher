import AppKit
import OSLog
import SharedModels

/// Core Graphics ベースのアノテーションキャンバス
/// マウスイベントで描画操作を行い、全アノテーションを合成描画する
public final class AnnotateCanvasView: NSView {
    public var document: AnnotateDocument? {
        didSet { needsDisplay = true }
    }

    /// 描画中の一時アイテム
    private var activeItem: AnnotationItem?

    /// テキスト編集用フィールド
    private var textField: NSTextField?

    override public var isFlipped: Bool { true }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Drawing

    override public func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let document else { return }

        let size = bounds.size

        // 背景（元画像）— isFlipped=true の CGContext で CGImage を正しく描画するためフリップ
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(document.originalImage, in: CGRect(origin: .zero, size: size))
        ctx.restoreGState()

        // 確定済みアノテーション（isFlipped 座標系でそのまま描画）
        AnnotateRenderer.render(items: document.items, in: ctx, size: size)

        // 描画中の一時アイテム
        if let activeItem {
            AnnotateRenderer.render(item: activeItem, in: ctx, size: size)
        }
    }

    // MARK: - Mouse Events

    override public func mouseDown(with event: NSEvent) {
        guard let document else { return }
        let point = convert(event.locationInWindow, from: nil)

        if document.currentTool == .text {
            startTextEditing(at: point)
            return
        }

        let item = AnnotationItem(
            toolType: document.currentTool,
            style: document.currentStyle,
            startPoint: point,
            endPoint: point
        )

        if document.currentTool == .pencil {
            item.points = [point]
        }

        if document.currentTool == .counter {
            item.counterNumber = document.nextCounterNumber
            document.nextCounterNumber += 1
            document.addItem(item)
            needsDisplay = true
            return
        }

        activeItem = item
    }

    override public func mouseDragged(with event: NSEvent) {
        guard let activeItem else { return }
        let point = convert(event.locationInWindow, from: nil)

        if activeItem.toolType == .pencil {
            activeItem.points.append(point)
        } else {
            activeItem.endPoint = point
        }

        needsDisplay = true
    }

    override public func mouseUp(with event: NSEvent) {
        guard let activeItem, let document else { return }
        let point = convert(event.locationInWindow, from: nil)

        if activeItem.toolType == .pencil {
            activeItem.points.append(point)
        } else {
            activeItem.endPoint = point
        }

        // サイズが十分あれば追加
        let rect = activeItem.boundingRect
        if rect.width > 2 || rect.height > 2 || activeItem.toolType == .pencil {
            document.addItem(activeItem)
        }

        self.activeItem = nil
        needsDisplay = true
    }

    // MARK: - Text Editing

    private func startTextEditing(at point: CGPoint) {
        guard let document else { return }

        // 既存のテキストフィールドがあれば確定
        finishTextEditing()

        let field = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 200, height: 30))
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = true
        field.font = NSFont(name: document.currentStyle.fontName, size: document.currentStyle.fontSize)
            ?? NSFont.systemFont(ofSize: document.currentStyle.fontSize)
        field.textColor = document.currentStyle.strokeColor
        field.focusRingType = .none
        field.target = self
        field.action = #selector(textFieldDidEndEditing(_:))
        field.placeholderString = "テキストを入力"

        addSubview(field)
        field.becomeFirstResponder()
        textField = field
    }

    @objc private func textFieldDidEndEditing(_ sender: NSTextField) {
        finishTextEditing()
    }

    private func finishTextEditing() {
        guard let field = textField, let document else { return }

        let text = field.stringValue
        if !text.isEmpty {
            let item = AnnotationItem(
                toolType: .text,
                style: document.currentStyle,
                startPoint: field.frame.origin,
                text: text
            )
            document.addItem(item)
        }

        field.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }

    // MARK: - Keyboard

    override public var acceptsFirstResponder: Bool { true }

    override public func keyDown(with event: NSEvent) {
        guard let document else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags
        let key = event.charactersIgnoringModifiers

        // ⌘Z = Undo, ⌘⇧Z = Redo
        if flags.contains(.command) && key == "z" {
            if flags.contains(.shift) {
                document.redo()
            } else {
                document.undo()
            }
            needsDisplay = true
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Export

    /// 現在の描画内容を CGImage としてエクスポート
    public func exportImage() -> CGImage? {
        guard let document else { return nil }

        let size = bounds.size
        let scale = window?.backingScaleFactor ?? 2.0
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)

        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        ctx.scaleBy(x: scale, y: scale)

        // 座標系を flipped に（isFlipped = true に合わせる）
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        // 元画像
        ctx.draw(document.originalImage, in: CGRect(origin: .zero, size: size))

        // アノテーション
        AnnotateRenderer.render(items: document.items, in: ctx, size: size)

        guard var image = ctx.makeImage() else { return nil }

        // クロップ適用
        if let cropRect = document.cropRect {
            let scaledCrop = CGRect(
                x: cropRect.origin.x * scale,
                y: cropRect.origin.y * scale,
                width: cropRect.width * scale,
                height: cropRect.height * scale
            )
            if let cropped = image.cropping(to: scaledCrop) {
                image = cropped
            }
        }

        return image
    }
}
