import Foundation

/// Поиск бинарников пакетных менеджеров (npm, pnpm, yarn, cargo).
/// Стораджи пакетных менеджеров НИКОГДА не удаляются через rm —
/// только родными командами (`npm cache clean --force`, `pnpm store prune` и т.д.).
enum PackageManagerCleaner {
    static func locate(_ names: [String]) -> String? {
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        for dir in dirs {
            for name in names {
                let candidate = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return nil
    }
}