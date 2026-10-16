import XCTest
@testable import DiskCleaner

final class SafetyGuardTests: XCTestCase {

    func testForbiddenKeychainPaths() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Keychains/login.keychain-db"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/Library/Keychains/System.keychain"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/creds.keychain"))
    }

    func testForbiddenPreferences() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Preferences/com.apple.finder.plist"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Group Containers/group.com.apple.test/Library/Preferences/foo.plist"))
    }

    func testForbiddenSSHAndGnuPGAndConfig() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.ssh/id_rsa"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.ssh/config"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.gnupg/pubring.kbx"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.config/foo/bar"))
    }

    func testForbiddenExtensions() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/secret.key"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/cert.pem"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/archive.p12"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/profile.mobileprovision"))
    }

    func testForbiddenNames() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/license.txt"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/activation.plist"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/token.json"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/tmp/credentials"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/SomeApp/License.dat"))
    }

    func testCloudStorageBlocked() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/CloudStorage/OneDrive/file.txt"))
        XCTAssertTrue(SafetyGuard.isCloudStoragePath("~/Library/CloudStorage/OneDrive"))
    }

    func testSwapFilesBlocked() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/System/Volumes/VM/swapfile0"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/System/Volumes/VM/swapfile1"))
    }

    func testTimeMachineSnapshotsBlocked() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/Volumes/Backup/Backups.backupdb/Mac/2026-10-01"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("/System/Volumes/Data/.MobileBackups/foo"))
    }

    func testAIAssistantProtected() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cursor/User/globalStorage/state.vscdb.backup"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/User/globalStorage/state.vscdb"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Claude/whatever"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Codex/whatever"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Continue/whatever"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cline/whatever"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Koda/whatever"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/User/globalStorage/foo.bin"))
    }

    func testAIAssistantCleanableSubpathsAllowed() {
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cursor/CachedData"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cursor/logs"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cursor/debugging-data"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Cursor/snapshots"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/CachedData"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/logs"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/Crashpad"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/CachedExtensionVSIXs"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Application Support/Code/agent-host/sdk-cache"))
    }

    func testPackageManagerStoresBlocked() {
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.npm/_cacache"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.npm/_npx"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.yarn/cache"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/.cargo/registry"))
        XCTAssertFalse(SafetyGuard.isAllowedForDeletion("~/Library/Caches/Homebrew"))
    }

    func testSafeJunkAllowed() {
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("/private/var/folders/xx/com.google.Chrome.code_sign_clone"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Caches/com.apple.Safari"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/HTTPStorages/com.apple.Safari"))
        XCTAssertTrue(SafetyGuard.isAllowedForDeletion("~/Library/Developer/Xcode/DerivedData/MyApp"))
    }

    func testExpandTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(SafetyGuard.expand("~/Library/Caches"), home + "/Library/Caches")
        XCTAssertEqual(SafetyGuard.expand("/tmp/x"), "/tmp/x")
    }
}