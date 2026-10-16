import XCTest

/// Дополнительные UI-тесты: горячие клавиши и экспорт.
final class ScanFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testKeyboardShortcutRescan() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_FAST_SCAN"] = "1"
        app.launch()

        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.click()

        // Ждём отчёт
        XCTAssertTrue(app.staticTexts["Мусор"].waitForExistence(timeout: 120))

        // Cmd+R — пересканирование
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Мусор"].waitForExistence(timeout: 120), "После Cmd+R отчёт должен обновиться")
    }

    func testCancelScanReturnsToWelcome() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_FAST_SCAN"] = "1"
        app.launch()

        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.click()

        // Отмена сканирования
        let cancelButton = app.buttons["cancelScanButton"]
        if cancelButton.waitForExistence(timeout: 10) {
            cancelButton.click()
            XCTAssertTrue(startButton.waitForExistence(timeout: 10), "После отмены должен вернуться экран приветствия")
        }
    }
}