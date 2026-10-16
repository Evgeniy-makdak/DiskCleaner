import XCTest

/// UI-тесты: полный сценарий «сканирование → отчёт → выбор → подтверждение → очистка».
/// Для скорости используется UITEST_FAST_SCAN (сканируются только лёгкие шаги).
final class DiskCleanerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFullScanFlow() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_FAST_SCAN"] = "1"
        app.launch()

        // Экран приветствия
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Кнопка «Начать сканирование» должна быть на экране")
        startButton.click()

        // Ждём отчёт (вкладка «Мусор»)
        let junkTab = app.staticTexts["Мусор"]
        XCTAssertTrue(junkTab.waitForExistence(timeout: 120), "Отчёт должен появиться после сканирования")

        // Кнопка очистки выбранного доступна
        let cleanButton = app.buttons["cleanSelectedButton"]
        XCTAssertTrue(cleanButton.waitForExistence(timeout: 10))
    }

    func testNothingDeletedWithoutConfirmation() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_FAST_SCAN"] = "1"
        app.launch()

        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.click()

        let cleanButton = app.buttons["cleanSelectedButton"]
        XCTAssertTrue(cleanButton.waitForExistence(timeout: 120))
        cleanButton.click()

        // Появляется модальное окно подтверждения
        let cancelButton = app.buttons["cancelCleanupButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10), "Без подтверждения очистка не должна начинаться")

        // Кнопка «Подтвердить удаление» заблокирована, пока не отмечен чекбокс
        let confirmButton = app.buttons["confirmDeleteButton"]
        XCTAssertFalse(confirmButton.isEnabled, "Подтверждение должно быть заблокировано до явного согласия")

        // Отменяем — ничего не удалено, приложение остаётся на отчёте
        cancelButton.click()
        XCTAssertTrue(app.staticTexts["Мусор"].waitForExistence(timeout: 10))
    }

    func testConfirmationRequiresExplicitConsent() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_FAST_SCAN"] = "1"
        app.launch()

        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.click()

        let cleanButton = app.buttons["cleanSelectedButton"]
        XCTAssertTrue(cleanButton.waitForExistence(timeout: 120))
        cleanButton.click()

        let confirmButton = app.buttons["confirmDeleteButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertFalse(confirmButton.isEnabled)

        // Отмечаем согласие — кнопка активируется
        let understandToggle = app.checkBoxes["understandToggle"]
        XCTAssertTrue(understandToggle.waitForExistence(timeout: 5))
        understandToggle.click()
        XCTAssertTrue(confirmButton.isEnabled, "После явного согласия кнопка должна активироваться")
    }
}