import XCTest
@testable import DiskCleaner

final class AnalyzerTests: XCTestCase {

    func testJunkClassification() {
        XCTAssertEqual(Analyzer.category(for: "/private/var/folders/xx/com.google.Chrome.code_sign_clone"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Caches/com.apple.Safari"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Caches"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Code/CachedData"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Code/logs"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Code/Crashpad"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Cursor/CachedData"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Cursor/logs"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Cursor/snapshots"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Cursor/debugging-data"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Google/GoogleUpdater/crx_cache"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/com.apple.wallpaper/aerials"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/HTTPStorages/com.apple.Safari"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Developer/Xcode/DerivedData"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Developer/CoreSimulator/Caches"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Caches/Homebrew"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/.npm/_cacache"), .junk)
        XCTAssertEqual(Analyzer.category(for: "~/.npm/_npx"), .junk)
    }

    func testUserDataClassification() {
        XCTAssertEqual(Analyzer.category(for: "/Applications/Xcode.app"), .userData)
        XCTAssertEqual(Analyzer.category(for: "~/Desktop/MyProject"), .userData)
        XCTAssertEqual(Analyzer.category(for: "~/Documents/Reports"), .userData)
        XCTAssertEqual(Analyzer.category(for: "~/Developer/App"), .userData)
        XCTAssertEqual(Analyzer.category(for: "~/Library/CloudStorage/OneDrive"), .userData)
        XCTAssertEqual(Analyzer.category(for: "~/Library/TinyTeX"), .userData)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/CrossOver/Bottles/win10"), .userData)
    }

    func testHistoryClassification() {
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"), .history)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Application Support/Code/User/globalStorage/state.vscdb"), .history)
        XCTAssertEqual(Analyzer.category(for: "~/.ssh/id_rsa"), .history)
        XCTAssertEqual(Analyzer.category(for: "~/.gnupg/pubring.kbx"), .history)
        XCTAssertEqual(Analyzer.category(for: "~/.config/foo"), .history)
        XCTAssertEqual(Analyzer.category(for: "~/Library/Keychains/login.keychain-db"), .history)
        XCTAssertEqual(Analyzer.category(for: "/tmp/secret.key"), .history)
        XCTAssertEqual(Analyzer.category(for: "/tmp/license.txt"), .history)
    }

    func testClassifyAssignsActions() {
        let findings = [
            RawFinding(path: "~/Library/Caches/com.apple.Safari", sizeBytes: 100, modifiedDate: nil, source: .cachesDu, kindHint: ""),
            RawFinding(path: "~/Library/CloudStorage/OneDrive", sizeBytes: 100, modifiedDate: nil, source: .cloudStorageDu, kindHint: ""),
            RawFinding(path: "~/.npm/_cacache", sizeBytes: 100, modifiedDate: nil, source: .packageManager, kindHint: ""),
            RawFinding(path: "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb", sizeBytes: 100, modifiedDate: nil, source: .vscdb, kindHint: ""),
        ]
        let items = Analyzer.classify(findings)
        XCTAssertEqual(items.count, 4)

        let byPath = Dictionary(uniqueKeysWithValues: items.map { ($0.path, $0) })
        XCTAssertEqual(byPath[SafetyGuard.expand("~/Library/Caches/com.apple.Safari")]?.action, .removeItem)
        XCTAssertEqual(byPath[SafetyGuard.expand("~/Library/CloudStorage/OneDrive")]?.action, .brctlEvict)
        XCTAssertEqual(byPath[SafetyGuard.expand("~/.npm/_cacache")]?.action, .npmCacheClean)
        XCTAssertEqual(byPath[SafetyGuard.expand("~/Library/Application Support/Cursor/User/globalStorage/state.vscdb")]?.action, .manual)
    }

    func testClassifyDeduplicatesPaths() {
        let findings = [
            RawFinding(path: "~/Library/Caches/com.apple.Safari", sizeBytes: 100, modifiedDate: nil, source: .cachesDu, kindHint: ""),
            RawFinding(path: "~/Library/Caches/com.apple.Safari", sizeBytes: 200, modifiedDate: nil, source: .knownPath, kindHint: ""),
        ]
        let items = Analyzer.classify(findings)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.sizeBytes, 200)
    }

    func testJunkSelectedByDefault() {
        let findings = [
            RawFinding(path: "~/Library/Caches/com.apple.Safari", sizeBytes: 100, modifiedDate: nil, source: .cachesDu, kindHint: ""),
            RawFinding(path: "~/Desktop/MyProject", sizeBytes: 100, modifiedDate: nil, source: .homeDu, kindHint: ""),
        ]
        let items = Analyzer.classify(findings)
        let junk = items.first { $0.category == .junk }
        let userData = items.first { $0.category == .userData }
        XCTAssertEqual(junk?.isSelected, true)
        XCTAssertEqual(userData?.isSelected, false)
    }
}