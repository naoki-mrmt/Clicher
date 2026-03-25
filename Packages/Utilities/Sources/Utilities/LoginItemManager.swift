import ServiceManagement
import OSLog
import Observation

/// ログイン時起動の管理（SMAppService）
@Observable
@MainActor
public final class LoginItemManager {
    /// ログイン時起動が有効かどうか
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public init() {}

    /// ログイン時起動を切り替え
    public func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
                Logger.loginItem.info("ログイン項目を解除しました")
            } else {
                try SMAppService.mainApp.register()
                Logger.loginItem.info("ログイン項目を登録しました")
            }
        } catch {
            Logger.loginItem.error("ログイン項目の変更に失敗: \(error)")
        }
    }
}
