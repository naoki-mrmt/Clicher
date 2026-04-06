import AppKit
import Carbon.HIToolbox
import OSLog

/// グローバルホットキー管理
/// `CGEvent.tapCreate` ベースでカスタマイズ可能なホットキーをシステム全体で監視する
@MainActor
public final class HotkeyManager: @unchecked Sendable {
    public static let shared = HotkeyManager()

    /// ホットキーが押された時のコールバック
    public var onHotkeyPressed: (@Sendable @MainActor () -> Void)?

    /// ホットキー登録失敗時のコールバック
    public var onRegistrationFailed: (@MainActor () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// CGEventTap callback からスレッド安全にアクセスするための参照
    /// callback は C function pointer でキャプチャ不可のため static 経由
    nonisolated(unsafe) private static var sharedEventTap: CFMachPort?

    /// カスタムホットキー設定（static で callback からアクセス）
    nonisolated(unsafe) private static var configuredKeyCode: Int64 = Int64(kVK_ANSI_A)
    nonisolated(unsafe) private static var configuredModifiers: CGEventFlags = [.maskCommand, .maskShift]

    private init() {}

    /// ホットキーのキー設定を更新
    /// - Parameters:
    ///   - keyCode: キーコード（Carbon kVK_* 定数）
    ///   - modifiers: 修飾キーフラグ（CGEventFlags）
    public func configure(keyCode: Int, modifiers: Int) {
        HotkeyManager.configuredKeyCode = Int64(keyCode)
        HotkeyManager.configuredModifiers = CGEventFlags(rawValue: UInt64(modifiers))
        Logger.hotkey.info("ホットキー設定更新: keyCode=\(keyCode), modifiers=\(modifiers)")
    }

    /// ホットキーの登録
    public func register() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // C function pointer — キャプチャ不可のため static 経由でアクセス
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = HotkeyManager.sharedEventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // カスタム設定されたキーと修飾キーをチェック
            let targetModifiers = HotkeyManager.configuredModifiers
            let targetKeyCode = HotkeyManager.configuredKeyCode

            let modifiersMatch = flags.contains(targetModifiers)
            let keyCodeMatch = keyCode == targetKeyCode

            if modifiersMatch && keyCodeMatch {
                Task { @MainActor in
                    HotkeyManager.shared.onHotkeyPressed?()
                }
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: nil
        )

        guard let eventTap else {
            Logger.hotkey.error("CGEvent.tapCreate failed — Accessibility 権限が必要です")
            onRegistrationFailed?()
            return
        }

        HotkeyManager.sharedEventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        Logger.hotkey.info("ホットキーを登録しました (keyCode=\(HotkeyManager.configuredKeyCode))")
    }

    /// ホットキーを再登録（タップを破棄→再作成して最高優先度を確保）
    /// 他アプリ（Lark等）より後にタップを作成することで headInsertEventTap の優先度を上げる
    public func reregister() {
        unregister()
        register()
    }

    /// ホットキーの解除
    public func unregister() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil
        HotkeyManager.sharedEventTap = nil
        Logger.hotkey.info("ホットキーを解除しました")
    }
}
