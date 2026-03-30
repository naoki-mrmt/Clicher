import XCTest

/// Clicher E2E UI テスト
/// アプリを起動して UI 要素の存在と基本操作を検証する
final class ClicherUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // メニューバーアプリなので少し待つ
        Thread.sleep(forTimeInterval: 1)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Menu Bar

    @MainActor
    func testMenuBarIconExists() throws {
        // メニューバーアイコンが表示されている
        let menuBar = app.menuBars
        XCTAssertTrue(menuBar.count > 0, "メニューバーが存在する")
    }

    // MARK: - Settings Window

    @MainActor
    func testSettingsWindowOpens() throws {
        // ⌘, で設定画面を開く
        app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // 設定ウィンドウが存在する
        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3), "設定ウィンドウが開く")
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
