import AppKit
import Observation
import OSLog
import SharedModels

/// アノテーションドキュメント
/// アノテーション要素の管理と Undo/Redo を提供
@Observable
@MainActor
public final class AnnotateDocument {
    /// 元画像
    public let originalImage: CGImage

    /// アノテーション要素リスト
    public private(set) var items: [AnnotationItem] = []

    /// Undo スタック
    private var undoStack: [[AnnotationItem]] = []

    /// Redo スタック
    private var redoStack: [[AnnotationItem]] = []

    /// 現在のスタイル設定
    public var currentStyle = AnnotationStyle()

    /// 現在選択中のツール
    public var currentTool: AnnotationToolType = .arrow

    /// カウンターの次の番号
    public var nextCounterNumber = 1

    /// クロップ範囲（nil = クロップなし）
    public var cropRect: CGRect?

    /// Undo 可能か
    public var canUndo: Bool { !undoStack.isEmpty }

    /// Redo 可能か
    public var canRedo: Bool { !redoStack.isEmpty }

    /// アイテム変更時のコールバック（キャンバス再描画用）
    public var onItemsChanged: (() -> Void)?

    public init(image: CGImage) {
        self.originalImage = image
    }

    // MARK: - Item Management

    /// アノテーション要素を追加
    public func addItem(_ item: AnnotationItem) {
        saveStateForUndo()
        items.append(item)
        redoStack.removeAll()
        onItemsChanged?()
        Logger.app.debug("アノテーション追加: \(item.toolType.rawValue)")
    }

    /// 最後のアノテーション要素を削除
    public func removeLastItem() {
        guard !items.isEmpty else { return }
        saveStateForUndo()
        items.removeLast()
        redoStack.removeAll()
        onItemsChanged?()
    }

    /// 指定 ID のアノテーション要素を削除
    public func removeItem(id: UUID) {
        saveStateForUndo()
        items.removeAll { $0.id == id }
        redoStack.removeAll()
        onItemsChanged?()
    }

    // MARK: - Undo / Redo

    /// Undo
    public func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(items.map { $0.copy() })
        items = previousState
        onItemsChanged?()
        Logger.app.debug("Undo 実行 (残りスタック: \(self.undoStack.count))")
    }

    /// Redo
    public func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(items.map { $0.copy() })
        items = nextState
        onItemsChanged?()
        Logger.app.debug("Redo 実行 (残りスタック: \(self.redoStack.count))")
    }

    /// 現在の状態を Undo スタックに保存（外部からの直接変更前に呼ぶ）
    public func saveSnapshot() {
        saveStateForUndo()
        redoStack.removeAll()
    }

    // MARK: - Private

    private func saveStateForUndo() {
        undoStack.append(items.map { $0.copy() })
        // メモリ節約のため最大50ステップ
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
