import AppKit
import SwiftUI

/// `canBecomeKey` を返す NSPanel サブクラス。
/// `.nonactivatingPanel` + borderless のパネルはデフォルトでキーウィンドウになれず、
/// ローカルキーモニタ（ESC・ショートカット等）にイベントが届かないため、
/// キーボード操作を受け付けるパネルはこのクラスを使う。
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// `acceptsFirstMouse` を返す NSHostingView サブクラス。
/// 非アクティブウィンドウでも最初のクリックでボタンが反応するようにする。
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
