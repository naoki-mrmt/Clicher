import ServiceManagement
import OSLog

/// ログイン時起動の管理（SMAppService）
@Observable
final class LoginItemManager {
    /// ログイン時起動が有効かどうか
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// ログイン時起動を切り替え
    func toggle() {
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
