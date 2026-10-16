import XCTest
@testable import DiskCleaner

final class CleanerTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskCleanerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    @discardableResult
    private func makeFile(_ name: String, size: Int = 1024) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try Data(repeating: 0x41, count: size).write(to: url)
        return url
    }

    private func makeItem(path: String, action: CleanAction = .removeItem, category: ScanCategory = .junk) -> ScanItem {
        ScanItem(
            path: path,
            sizeBytes: 1024,
            category: category,
            kind: "test",
            freedImmediately: true,
            requiresPrivileges: false,
            isSelected: true,
            modifiedDate: nil,
            source: .knownPath,
            action: action,
            note: nil
        )
    }

    func testOnlyApprovedPathsAreDeleted() throws {
        let approved = try makeFile("approved.bin")
        let notApproved = try makeFile("notApproved.bin")

        let cleaner = Cleaner()
        var progressItems: [CleanedItem] = []
        let report = cleaner.clean(items: [makeItem(path: approved.path)], useTrash: false) {
            progressItems.append($0)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: approved.path), "Одобренный путь должен быть удалён")
        XCTAssertTrue(FileManager.default.fileExists(atPath: notApproved.path), "Неодобренный путь не должен быть удалён")
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(report.items.first?.result, .success)
        XCTAssertEqual(progressItems.count, 1)
    }

    func testForbiddenPathIsSkippedEvenIfApproved() throws {
        // Имя файла содержит "secret" — SafetyGuard обязан заблокировать.
        let forbidden = tempDir.appendingPathComponent("secret.key")
        try Data(repeating: 0x42, count: 100).write(to: forbidden)

        let cleaner = Cleaner()
        let report = cleaner.clean(items: [makeItem(path: forbidden.path)], useTrash: false) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: forbidden.path), "Запрещённый путь не должен быть удалён")
        XCTAssertEqual(report.items.first?.result, .skipped)
    }

    func testCloudStoragePathIsSkipped() throws {
        // Путь, похожий на CloudStorage, не должен удаляться через removeItem.
        let cloudLike = tempDir.appendingPathComponent("Library/CloudStorage/OneDrive/file.txt")
        try FileManager.default.createDirectory(at: cloudLike.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x43, count: 100).write(to: cloudLike)

        let cleaner = Cleaner()
        let report = cleaner.clean(items: [makeItem(path: cloudLike.path)], useTrash: false) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: cloudLike.path))
        XCTAssertEqual(report.items.first?.result, .skipped)
    }

    func testTrashModeMovesToTrash() throws {
        let file = try makeFile("trashme.bin")
        let cleaner = Cleaner()
        let report = cleaner.clean(items: [makeItem(path: file.path)], useTrash: true) { _ in }

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(report.items.first?.result, .success)
        XCTAssertTrue(report.usedTrash)
    }

    func testMissingPathReportsFailure() {
        let missing = tempDir.appendingPathComponent("does-not-exist.bin")
        let cleaner = Cleaner()
        let report = cleaner.clean(items: [makeItem(path: missing.path)], useTrash: false) { _ in }

        XCTAssertEqual(report.items.first?.result, .failed)
        XCTAssertEqual(report.failedCount, 1)
    }

    func testManualActionIsNotExecuted() throws {
        let file = try makeFile("manual.bin")
        let cleaner = Cleaner()
        let report = cleaner.clean(items: [makeItem(path: file.path, action: .manual, category: .history)], useTrash: false) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "manual-действие не должно удалять файл")
        XCTAssertEqual(report.items.first?.result, .requiresManual)
    }
}