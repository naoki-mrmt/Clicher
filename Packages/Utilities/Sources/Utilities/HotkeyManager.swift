import AppKit
import Carbon.HIToolbox
import OSLog

/// グローバルホットキー管理
/// `CGEvent.tapCreate` ベースで ⌘⇧A をシステム全体で監視する
public final class HotkeyManager: @unchecked Sendable {
    public static let shared = HotkeyManager()

    /// ホットキーが押された時のコールバック
    public var onHotkeyPressed: (@Sendable @MainActor () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    /// ホットキーの登録
    public func register() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // C function pointer — キャプチャ不可のためstatic経由でself参照
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // タップが無効化された場合は再有効化
                if let tap = HotkeyManager.shared.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passRetained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // ⌘⇧A: keyCode 0 = 'A', flags に .maskCommand と .maskShift
            let isCommand = flags.contains(.maskCommand)
            let isShift = flags.contains(.maskShift)
            let isA = keyCode == Int64(kVK_ANSI_A)

            if isCommand && isShift && isA {
                Task { @MainActor in
                    HotkeyManager.shared.onHotkeyPressed?()
                }
                // イベントを消費（他アプリに渡さない）
                return nil
            }

            return Unmanaged.passRetained(event)
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
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        Logger.hotkey.info("⌘⇧A ホットキーを登録しました")
    }

    /// ホットキーの解除
    public func unregister() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        Logger.hotkey.info("ホットキーを解除しました")
    }
}
