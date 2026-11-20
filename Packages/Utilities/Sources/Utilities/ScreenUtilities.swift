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

    /// CGDirectDisplayID から対応する NSScreen を返す
    /// 見つからなければ nil（ディスプレイ切断直後等）
    public static func screen(forDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { self.displayID(for: $0) == displayID }
    }

    /// 指定ディスプレイの backingScaleFactor を返す
    /// 対応するスクリーンが見つからなければメインスクリーンの値にフォールバック
    public static func scaleFactor(forDisplayID displayID: CGDirectDisplayID) -> CGFloat {
        screen(forDisplayID: displayID)?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
    }

    // MARK: - Global Coordinate Flips

    /// グローバル座標の Y 反転に使う基準高さ
    /// AppKit（左下原点）と CG/SCK（左上原点）の両座標系は原点がメイン（プライマリ）
    /// ディスプレイにあるため、必ずプライマリスクリーン（NSScreen.screens.first）の高さを使う
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// グローバル座標系の矩形を上下反転する
    /// AppKit グローバル座標（左下原点）↔ CG/SCK グローバル座標（左上原点）の相互変換に使う
    /// （変換は対合なので、どちらの向きにも同じ関数を使える）
    /// - Parameter rect: グローバル座標の矩形
    /// - Returns: 反転後のグローバル座標の矩形
    public static func flipFromGlobalTopLeft(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// グローバル座標系の Y 値を上下反転する
    /// AppKit グローバル座標（左下原点）↔ CG/SCK グローバル座標（左上原点）の相互変換に使う
    /// - Parameter y: グローバル座標の Y 値
    /// - Returns: 反転後の Y 値
    public static func flipGlobalY(_ y: CGFloat) -> CGFloat {
        primaryScreenHeight - y
    }
}
