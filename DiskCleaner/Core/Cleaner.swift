import Foundation

/// Выполняет удаление ТОЛЬКО того, что пользователь одобрил через UI.
/// Каждый путь повторно проверяется SafetyGuard перед удалением.
struct Cleaner {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func clean(
        items: [ScanItem],
        useTrash: Bool,
        approvedBy: String = NSFullUserName(),
        progress: @escaping (CleanedItem) -> Void
    ) -> CleaningReport {
        var report = CleaningReport()
        report.usedTrash = useTrash
        report.freeBefore = DiskSpace.freeBytes()

        for item in items {
            let path = SafetyGuard.expand(item.path)

            // Финальная проверка SafetyGuard — даже если путь был одобрен в UI.
            guard SafetyGuard.isAllowedForDeletion(path) else {
                let cleaned = CleanedItem(item: item, result: .skipped, message: L.string("clean.skippedByGuard"), freedBytes: 0)
                report.items.append(cleaned)
                report.skippedCount += 1
                progress(cleaned)
                continue
            }

            // Снимок действия в лог ДО удаления: путь, размер, дата, хеш, кто одобрил.
            let hash = Logger.sha256(ofFile: path)
            Logger.shared.logAction(LogEntry(
                timestamp: Date(),
                action: "delete-approved",
                path: path,
                sizeBytes: item.sizeBytes,
                sha256: hash,
                approvedBy: approvedBy,
                result: "approved",
                usedTrash: useTrash
            ))

            let outcome = perform(item: item, path: path, useTrash: useTrash)
            let cleaned = CleanedItem(item: item, result: outcome.status, message: outcome.message, freedBytes: outcome.freedBytes)
            report.items.append(cleaned)
            report.freedBytes += outcome.freedBytes
            switch outcome.status {
            case .success: break
            case .skipped, .requiresManual: report.skippedCount += 1
            case .failed: report.failedCount += 1
            }

            Logger.shared.logAction(LogEntry(
                timestamp: Date(),
                action: "delete-result",
                path: path,
                sizeBytes: item.sizeBytes,
                sha256: hash,
                approvedBy: approvedBy,
                result: outcome.status.rawValue,
                usedTrash: useTrash
            ))

            progress(cleaned)
        }

        report.freeAfter = DiskSpace.freeBytes()
        report.finishedAt = Date()
        return report
    }

    // MARK: - Выполнение операции

    private func perform(item: ScanItem, path: String, useTrash: Bool) -> (status: CleanResult, message: String, freedBytes: Int64) {
        switch item.action {
        case .npmCacheClean:
            return runPackageCommand(["npm"], args: ["cache", "clean", "--force"], item: item)
        case .pnpmStorePrune:
            return runPackageCommand(["pnpm"], args: ["store", "prune"], item: item)
        case .yarnCacheClean:
            return runPackageCommand(["yarn"], args: ["cache", "clean"], item: item)
        case .cargoCacheAutoclean:
            return runPackageCommand(["cargo"], args: ["cache", "--autoclean"], item: item)
        case .brctlEvict:
            // Облачные файлы: выгрузка локальной копии, НЕ удаление.
            let r = CommandRunner.run("/usr/bin/brctl", arguments: ["evict", path], timeout: 120)
            if r.exitCode == 0 {
                return (.success, "brctl evict: OK", item.sizeBytes)
            }
            return (.failed, r.stderr.trimmed.isEmpty ? "brctl evict failed" : r.stderr.trimmed, 0)
        case .manual:
            return (.requiresManual, L.string("clean.manual"), 0)
        case .removeItem, .trashItem:
            return removeOrTrash(path: path, useTrash: useTrash, item: item)
        }
    }

    private func runPackageCommand(_ names: [String], args: [String], item: ScanItem) -> (status: CleanResult, message: String, freedBytes: Int64) {
        guard let binary = PackageManagerCleaner.locate(names) else {
            return (.failed, "\(names[0]) not found", 0)
        }
        let r = CommandRunner.run(binary, arguments: args, timeout: 300)
        if r.exitCode == 0 {
            return (.success, "\(names[0]) \(args.joined(separator: " ")): OK", item.sizeBytes)
        }
        return (.failed, r.stderr.trimmed.isEmpty ? "\(names[0]) failed" : r.stderr.trimmed, 0)
    }

    private func removeOrTrash(path: String, useTrash: Bool, item: ScanItem) -> (status: CleanResult, message: String, freedBytes: Int64) {
        let url = URL(fileURLWithPath: path)
        do {
            if useTrash {
                var resulting: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &resulting)
            } else {
                try fileManager.removeItem(at: url)
            }
            return (.success, "OK", item.sizeBytes)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == 513 {
                // Operation not permitted — SIP/TCC. Это норма, не баг.
                return (.failed, "Operation not permitted (SIP/TCC)", 0)
            }
            return (.failed, error.localizedDescription, 0)
        }
    }
}