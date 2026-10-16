import Foundation

/// Генерация отчётов: Markdown и JSON. Полностью офлайн.
struct Reporter {
    static func markdownReport(from result: ScanResult) -> String {
        var md = "# Отчёт Disk Cleaner\n\n"
        md += "- Дата: \(result.finishedAt.formatted(date: .abbreviated, time: .shortened))\n"
        md += "- macOS: \(result.systemInfo.osVersion) (\(result.systemInfo.architecture))\n"
        md += "- Занято: \(Formatters.byteCount(result.systemInfo.diskTotalBytes - result.systemInfo.diskFreeBytes)) / Свободно: \(Formatters.byteCount(result.systemInfo.diskFreeBytes))\n"
        md += "- Найдено мусора: \(Formatters.byteCount(result.junkBytes))\n\n"

        md += "## Мусор\n\n| Размер | Путь | Что это | Освободится |\n|---|---|---|---|\n"
        for item in result.junkItems {
            md += "| \(item.displaySize) | `\(item.path)` | \(item.kind) | \(item.freedImmediately ? "сразу" : "после перезагрузки") |\n"
        }

        md += "\n## Данные пользователя\n\n| Размер | Путь | Что это |\n|---|---|---|\n"
        for item in result.userDataItems {
            md += "| \(item.displaySize) | `\(item.path)` | \(item.kind) |\n"
        }

        md += "\n## Истории/Конфиги (защищено)\n\n| Размер | Путь | Что это |\n|---|---|---|\n"
        for item in result.historyItems {
            md += "| \(item.displaySize) | `\(item.path)` | \(item.kind) |\n"
        }

        if !result.errors.isEmpty {
            md += "\n## Ошибки\n\n"
            for e in result.errors {
                md += "- `\(e.command)`: \(e.message)\n"
            }
        }
        return md
    }

    static func jsonReport(from result: ScanResult) -> Data {
        struct EncodableItem: Codable {
            let path: String
            let sizeBytes: Int64
            let category: String
            let kind: String
            let freedImmediately: Bool
            let requiresPrivileges: Bool
        }
        struct ReportPayload: Codable {
            let generatedAt: String
            let osVersion: String
            let architecture: String
            let diskTotalBytes: Int64
            let diskFreeBytes: Int64
            let junkBytes: Int64
            let items: [EncodableItem]
        }
        let payload = ReportPayload(
            generatedAt: ISO8601DateFormatter().string(from: result.finishedAt),
            osVersion: result.systemInfo.osVersion,
            architecture: result.systemInfo.architecture,
            diskTotalBytes: result.systemInfo.diskTotalBytes,
            diskFreeBytes: result.systemInfo.diskFreeBytes,
            junkBytes: result.junkBytes,
            items: result.items.map {
                EncodableItem(
                    path: $0.path,
                    sizeBytes: $0.sizeBytes,
                    category: $0.category.rawValue,
                    kind: $0.kind,
                    freedImmediately: $0.freedImmediately,
                    requiresPrivileges: $0.requiresPrivileges
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(payload)) ?? Data()
    }

    static func cleaningReportMarkdown(_ report: CleaningReport) -> String {
        var md = "# Отчёт об очистке\n\n"
        md += "- Начало: \(report.startedAt.formatted(date: .abbreviated, time: .shortened))\n"
        md += "- Окончание: \(report.finishedAt.formatted(date: .abbreviated, time: .shortened))\n"
        md += "- Освобождено: \(Formatters.byteCount(report.freedBytes))\n"
        md += "- Пропущено: \(report.skippedCount), Ошибок: \(report.failedCount)\n"
        md += "- Режим: \(report.usedTrash ? "Корзина" : "Удаление")\n\n"
        md += "| Результат | Размер | Путь | Сообщение |\n|---|---|---|---|\n"
        for item in report.items {
            md += "| \(item.result.rawValue) | \(item.item.displaySize) | `\(item.item.path)` | \(item.message) |\n"
        }
        return md
    }
}