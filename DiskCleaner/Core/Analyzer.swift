import Foundation

/// Классифицирует найденные объекты по трём корзинам:
/// junk (безопасно вернуть), userData (решение пользователя), history (не трогать).
struct Analyzer {
    static func classify(_ findings: [RawFinding]) -> [ScanItem] {
        var seen = Set<String>()
        var items: [ScanItem] = []
        for f in findings.sorted(by: { $0.sizeBytes > $1.sizeBytes }) {
            let path = SafetyGuard.expand(f.path)
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            let category = category(for: path, source: f.source)
            let action = cleanAction(for: path, category: category)
            let item = ScanItem(
                path: path,
                sizeBytes: f.sizeBytes,
                category: category,
                kind: kindDescription(for: path, source: f.source),
                freedImmediately: freedImmediately(for: path, category: category),
                requiresPrivileges: f.requiresPrivileges,
                isSelected: category == .junk,
                modifiedDate: f.modifiedDate,
                source: f.source,
                action: action,
                note: note(for: path, category: category)
            )
            items.append(item)
        }
        return items
    }

    // MARK: - Классификация

    static func category(for path: String, source: ScanSource = .knownPath) -> ScanCategory {
        let p = SafetyGuard.expand(path)
        let lower = p.lowercased()

        // Облачные хранилища — данные пользователя (только evict, не удаление).
        if SafetyGuard.isCloudStoragePath(p) { return .userData }

        // Стораджи пакетных менеджеров — мусор, но чистится родными командами.
        if SafetyGuard.isPackageManagerStore(p) { return .junk }

        // Всё, что запрещено SafetyGuard, — в корзину history (не трогать).
        if !SafetyGuard.isAllowedForDeletion(p) { return .history }

        // --- Junk ---
        if lower.contains(".code_sign_clone") { return .junk }
        if lower.contains("com.apple.wallpaper/aerials") { return .junk }
        if lower.contains("googleupdater/crx_cache") { return .junk }
        if lower.contains("cachedextensionvsixs") { return .junk }
        if lower.contains("agent-host/sdk-cache") { return .junk }
        if lower.contains("/application support/") && lower.contains("/crashpad") { return .junk }
        if lower.contains("/library/") && lower.contains("/cacheddata") { return .junk }
        if lower.contains("/application support/") && lower.contains("/debugging-data") { return .junk }
        if lower.contains("/application support/") && lower.contains("/snapshots") { return .junk }
        if lower.contains("/httpstorages/") || lower.hasSuffix("/httpstorages") { return .junk }
        if lower.contains("gitkrakencli/versions") { return .junk }
        if lower.contains("/deriveddata") { return .junk }
        if lower.contains("/coresimulator/caches") { return .junk }
        if lower.contains("/caches/homebrew") { return .junk }
        if lower.contains("/library/caches/") || lower.hasSuffix("/library/caches") { return .junk }
        if lower.contains("/library/logs/") || lower.hasSuffix("/library/logs") { return .junk }

        // --- History ---
        if lower.contains("state.vscdb") || lower.contains("conversation-search.db") { return .history }
        if lower.contains("/user/globalstorage/") { return .history }
        if lower.contains("/.ssh") || lower.contains("/.gnupg") || lower.contains("/.config") { return .history }
        if lower.contains("keychain") { return .history }

        // --- User data ---
        if lower.hasPrefix("/applications/") || lower == "/applications" { return .userData }
        if lower.contains("/desktop/") || lower.contains("/documents/") || lower.contains("/developer/") { return .userData }
        if lower.contains("tinytex") { return .userData }
        if lower.contains("crossover") || lower.contains("wine") { return .userData }

        return .userData
    }

    // MARK: - Действие очистки

    static func cleanAction(for path: String, category: ScanCategory) -> CleanAction {
        let p = SafetyGuard.expand(path)
        if category == .history { return .manual }
        if SafetyGuard.isCloudStoragePath(p) { return .brctlEvict }
        if p.contains("/.npm/") { return .npmCacheClean }
        if p.contains("/pnpm") { return .pnpmStorePrune }
        if p.contains("/.yarn/") { return .yarnCacheClean }
        if p.contains("/.cargo/") { return .cargoCacheAutoclean }
        return .removeItem
    }

    // MARK: - Описание

    static func kindDescription(for path: String, source: ScanSource) -> String {
        let p = SafetyGuard.expand(path)
        let lower = p.lowercased()
        if lower.contains(".code_sign_clone") { return L.string("kind.codeSignClone") }
        if lower.contains("com.apple.wallpaper/aerials") { return L.string("kind.aerials") }
        if lower.contains("googleupdater/crx_cache") { return L.string("kind.crxCache") }
        if lower.contains("cachedextensionvsixs") { return L.string("kind.cachedVsix") }
        if lower.contains("agent-host/sdk-cache") { return L.string("kind.sdkCache") }
        if lower.contains("/crashpad") { return L.string("kind.crashpad") }
        if lower.contains("/cacheddata") { return L.string("kind.cachedData") }
        if lower.contains("/debugging-data") { return L.string("kind.debuggingData") }
        if lower.contains("/snapshots") { return L.string("kind.snapshots") }
        if lower.contains("/httpstorages/") { return L.string("kind.httpStorages") }
        if lower.contains("gitkrakencli/versions") { return L.string("kind.gitkraken") }
        if lower.contains("/.npm/") { return L.string("kind.npm") }
        if lower.contains("/pnpm") { return L.string("kind.pnpm") }
        if lower.contains("/.yarn/") { return L.string("kind.yarn") }
        if lower.contains("/.cargo/") { return L.string("kind.cargo") }
        if lower.contains("/deriveddata") { return L.string("kind.derivedData") }
        if lower.contains("/coresimulator") { return L.string("kind.coreSimulator") }
        if lower.contains("/caches/homebrew") { return L.string("kind.homebrew") }
        if lower.contains("/library/caches/") { return L.string("kind.caches") }
        if lower.contains("state.vscdb") { return L.string("kind.vscdb") }
        if lower.contains("conversation-search.db") { return L.string("kind.conversationDb") }
        if lower.contains("/user/globalstorage/") { return L.string("kind.globalStorage") }
        if lower.contains("/.ssh") { return L.string("kind.ssh") }
        if lower.contains("/.gnupg") { return L.string("kind.gnupg") }
        if lower.contains("/.config") { return L.string("kind.config") }
        if lower.contains("keychain") { return L.string("kind.keychain") }
        if lower.contains("/library/cloudstorage") { return L.string("kind.icloud") }
        if lower.contains("tinytex") { return L.string("kind.tinytex") }
        if lower.contains("crossover") { return L.string("kind.crossover") }
        if lower.contains("/applications/") || p == "/Applications" { return L.string("kind.apps") }
        if lower.contains("/desktop/") { return L.string("kind.desktop") }
        if lower.contains("/documents/") { return L.string("kind.documents") }
        if lower.contains("/developer/") { return L.string("kind.developer") }
        switch source {
        case .bigFiles: return L.string("kind.bigFile")
        case .dragAndDrop: return L.string("kind.folder")
        default: return L.string("kind.folder")
        }
    }

    // MARK: - Когда освободится место

    static func freedImmediately(for path: String, category: ScanCategory) -> Bool {
        let p = SafetyGuard.expand(path)
        let lower = p.lowercased()
        if lower.contains(".code_sign_clone") { return true }
        if lower.contains("/library/caches/") { return true }
        if lower.contains("/httpstorages/") { return true }
        if lower.contains("/deriveddata") { return false } // Xcode может держать файлы
        if lower.contains("/coresimulator") { return false }
        if lower.contains("/library/cloudstorage") { return false } // evict: место вернётся после выгрузки
        return true
    }

    // MARK: - Примечания

    static func note(for path: String, category: ScanCategory) -> String? {
        if category == .history { return L.string("note.history") }
        if SafetyGuard.isCloudStoragePath(path) { return L.string("note.icloud") }
        if SafetyGuard.isPackageManagerStore(path) { return L.string("note.pkgManager") }
        return nil
    }
}