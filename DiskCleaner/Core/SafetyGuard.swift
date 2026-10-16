import Foundation

/// Единственный источник правды о том, какие пути можно удалять.
/// Любой путь, не прошедший проверку, отклоняется — даже если пользователь
/// одобрил его в UI. Это финальный рубеж безопасности.
struct SafetyGuard {
    // MARK: - Запрещённые фрагменты путей

    static let forbiddenPathFragments: [String] = [
        "/Library/Keychains",
        "/Keychains/",
        "/.ssh",
        "/.gnupg",
        "/.config",
        "/Library/Preferences",
        "/Group Containers/",
        "/CloudStorage/",
        "/System/Volumes/VM/",
        "/.Trash/",
        "/.MobileBackups",
        "/Backups.backupdb",
    ]

    // MARK: - Запрещённые имена файлов

    static let forbiddenFileNames: [String] = [
        "license", "activation", "token", "secret", "credentials",
        "state.vscdb", "conversation-search.db",
    ]

    // MARK: - Запрещённые расширения

    static let forbiddenExtensions: [String] = [
        "keychain", "key", "pem", "p12", "pfx", "mobileprovision",
    ]

    // MARK: - AI-ассистенты: защищённые и чистящиеся подпапки

    static let aiAssistantDirs: [String] = [
        "Cursor", "Code", "Claude", "Codex", "Continue", "Cline", "Koda",
    ]

    static let aiAssistantProtectedSubpaths: [String] = [
        "/User/globalStorage/",
    ]

    static let aiAssistantCleanableSubpaths: [String] = [
        "/CachedData", "/logs", "/Crashpad", "/CachedExtensionVSIXs",
        "/snapshots", "/debugging-data", "/WebStorage", "/agent-host/sdk-cache",
    ]

    // MARK: - Стораджи пакетных менеджеров (только родные команды)

    static let packageManagerStores: [String] = [
        "/.npm/_cacache", "/.npm/_npx", "/.yarn/cache", "/.cache/yarn",
        "/.cargo/registry", "/Library/Caches/Homebrew", "/pnpm",
    ]

    // MARK: - Проверки

    /// Можно ли удалять этот путь. `false` = путь защищён.
    static func isAllowedForDeletion(_ path: String) -> Bool {
        let expanded = expand(path)

        if isCloudStoragePath(expanded) { return false }
        if isPackageManagerStore(expanded) { return false }
        if isAIAssistantProtected(expanded) { return false }
        if isSwapFile(expanded) { return false }
        if isTimeMachineSnapshot(expanded) { return false }

        let lower = expanded.lowercased()
        for fragment in forbiddenPathFragments where lower.contains(fragment.lowercased()) {
            return false
        }

        let name = (expanded as NSString).lastPathComponent.lowercased()
        for fname in forbiddenFileNames where name.contains(fname) {
            return false
        }

        let ext = (expanded as NSString).pathExtension.lowercased()
        if forbiddenExtensions.contains(ext) { return false }

        // License* в Application Support
        if lower.contains("/application support/") && name.hasPrefix("license") {
            return false
        }

        return true
    }

    static func isCloudStoragePath(_ path: String) -> Bool {
        expand(path).contains("/Library/CloudStorage/")
    }

    static func isPackageManagerStore(_ path: String) -> Bool {
        let expanded = expand(path)
        for store in packageManagerStores where expanded.contains(store) {
            return true
        }
        return false
    }

    /// Защищённые данные AI-ассистентов (истории, конфиги, state.vscdb).
    /// Разрешены только регенерируемые подпапки из aiAssistantCleanableSubpaths.
    static func isAIAssistantProtected(_ path: String) -> Bool {
        let expanded = expand(path)
        for dir in aiAssistantDirs {
            let marker = "/Application Support/\(dir)"
            guard let range = expanded.range(of: marker) else { continue }

            for sub in aiAssistantProtectedSubpaths where expanded.contains(marker + sub) {
                return true
            }
            if expanded.contains("state.vscdb") { return true }

            // Остаток пути ПОСЛЕ маркера (например "/CachedData").
            let remainder = String(expanded[range.upperBound...])
            if remainder.isEmpty { return true }
            for cleanable in aiAssistantCleanableSubpaths where remainder.hasPrefix(cleanable) {
                return false
            }
            return true
        }
        return false
    }

    static func isSwapFile(_ path: String) -> Bool {
        let expanded = expand(path)
        return expanded.hasPrefix("/System/Volumes/VM/") && expanded.contains("swapfile")
    }

    static func isTimeMachineSnapshot(_ path: String) -> Bool {
        let expanded = expand(path)
        return expanded.contains("/.MobileBackups") || expanded.contains("/Backups.backupdb")
    }

    /// Раскрывает `~` в полный путь.
    static func expand(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser.path + path.dropFirst(1)
        }
        return (path as NSString).expandingTildeInPath
    }
}