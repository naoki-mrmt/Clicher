import AppKit

/// マルチディスプレイ対応のスクリーンユーティリティ
public enum ScreenUtilities {
    /// マウスカーソルがあるスクリーンを返す。見つからなければメインスクリーンにフォールバック
    public static var activeScreen: NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
        return screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    /// アクティブスクリーンの frame
    public static var activeScreenFrame: CGRect {
        activeScreen.frame
    }

    /// アクティブスクリーンの visibleFrame（メニューバー・Dock を除く）
    public static var activeVisibleFrame: CGRect {
        activeScreen.visibleFrame
    }

    /// アクティブスクリーンの backingScaleFactor
    public static var activeScaleFactor: CGFloat {
        activeScreen.backingScaleFactor
    }
}
