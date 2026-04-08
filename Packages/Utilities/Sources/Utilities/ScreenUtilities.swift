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

    /// 指定された macOS 座標の矩形を含むスクリーンを返す
    public static func screen(containing rect: CGRect) -> NSScreen {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) }
        return screen ?? activeScreen
    }

    /// NSScreen から対応する CGDirectDisplayID を取得
    public static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
