import AppKit
import Carbon.HIToolbox

/// グローバルホットキーの管理
@Observable
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onAreaCapture: (() -> Void)?
    var onWindowCapture: (() -> Void)?
    var onFullscreenCapture: (() -> Void)?

    /// ホットキー監視を開始
    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // weak self で循環参照を避ける
        let callback: CGEventTapCallBack = { _, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(type: type, event: event)
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: pointer
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// ホットキー監視を停止
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Private

    private nonisolated func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        let isCommandShift = flags.contains([.maskCommand, .maskShift])

        // ⌘⇧4 → Area Capture
        if isCommandShift, keyCode == Int64(kVK_ANSI_4) {
            Task { @MainActor [weak self] in
                self?.onAreaCapture?()
            }
            return nil // イベントを消費
        }

        // ⌘⇧5 → Window Capture
        if isCommandShift, keyCode == Int64(kVK_ANSI_5) {
            Task { @MainActor [weak self] in
                self?.onWindowCapture?()
            }
            return nil
        }

        // ⌘⇧6 → Fullscreen Capture
        if isCommandShift, keyCode == Int64(kVK_ANSI_6) {
            Task { @MainActor [weak self] in
                self?.onFullscreenCapture?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
