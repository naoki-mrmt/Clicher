import AppKit
import Observation
import OSLog

/// アノテーションドキュメント
/// アノテーション要素の管理と Undo/Redo を提供
@Observable
final class AnnotateDocument {
    /// 元画像
    let originalImage: CGImage

    /// アノテーション要素リスト
    private(set) var items: [AnnotationItem] = []

    /// Undo スタック
    private var undoStack: [[AnnotationItem]] = []

    /// Redo スタック
    private var redoStack: [[AnnotationItem]] = []

    /// 現在のスタイル設定
    var currentStyle = AnnotationStyle()

    /// 現在選択中のツール
    var currentTool: AnnotationToolType = .arrow

    /// カウンターの次の番号
    var nextCounterNumber = 1

    /// クロップ範囲（nil = クロップなし）
    var cropRect: CGRect?

    /// Undo 可能か
    var canUndo: Bool { !undoStack.isEmpty }

    /// Redo 可能か
    var canRedo: Bool { !redoStack.isEmpty }

    init(image: CGImage) {
        self.originalImage = image
    }

    // MARK: - Item Management

    /// アノテーション要素を追加
    func addItem(_ item: AnnotationItem) {
        saveStateForUndo()
        items.append(item)
        redoStack.removeAll()
        Logger.app.debug("アノテーション追加: \(item.toolType.rawValue)")
    }

    /// 最後のアノテーション要素を削除
    func removeLastItem() {
        guard !items.isEmpty else { return }
        saveStateForUndo()
        items.removeLast()
        redoStack.removeAll()
    }

    // MARK: - Undo / Redo

    /// Undo
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(items)
        items = previousState
        Logger.app.debug("Undo 実行 (残りスタック: \(self.undoStack.count))")
    }

    /// Redo
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(items)
        items = nextState
        Logger.app.debug("Redo 実行 (残りスタック: \(self.redoStack.count))")
    }

    // MARK: - Private

    private func saveStateForUndo() {
        undoStack.append(items)
        // メモリ節約のため最大50ステップ
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
