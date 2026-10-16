import Foundation

// MARK: - System info

struct SystemInfo {
    var osVersion: String = ""
    var architecture: String = ""
    var diskTotalBytes: Int64 = 0
    var diskFreeBytes: Int64 = 0
    var apfsSummary: String = ""
    var localSnapshots: [String] = []
}

// MARK: - Scan error

struct ScanError: Identifiable {
    let id = UUID()
    var command: String
    var message: String
    var requiresPrivileges: Bool
}

// MARK: - Progress

struct ScanProgress {
    var currentStep: String = ""
    var fraction: Double = 0
    var foundBytes: Int64 = 0
    var isRunning: Bool = false
}

// MARK: - Scan result

struct ScanResult {
    var items: [ScanItem] = []
    var systemInfo = SystemInfo()
    var errors: [ScanError] = []
    var startedAt = Date()
    var finishedAt = Date()

    var junkItems: [ScanItem] { items.filter { $0.category == .junk } }
    var userDataItems: [ScanItem] { items.filter { $0.category == .userData } }
    var historyItems: [ScanItem] { items.filter { $0.category == .history } }

    var junkBytes: Int64 { junkItems.reduce(0) { $0 + $1.sizeBytes } }
    var userDataBytes: Int64 { userDataItems.reduce(0) { $0 + $1.sizeBytes } }
    var historyBytes: Int64 { historyItems.reduce(0) { $0 + $1.sizeBytes } }

    var biggestSurprise: ScanItem? {
        userDataItems.max { $0.sizeBytes < $1.sizeBytes }
    }

    /// Топ-5 файлов, изменённых за последние 7 дней.
    var recentGrowth: [ScanItem] {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        return items
            .filter { $0.modifiedDate != nil && $0.modifiedDate! > cutoff }
            .sorted { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Cleaning

enum CleanResult: String {
    case success
    case skipped
    case failed
    case requiresManual
}

struct CleanedItem: Identifiable {
    var id: UUID { item.id }
    var item: ScanItem
    var result: CleanResult
    var message: String
    var freedBytes: Int64
}

struct CleaningReport {
    var items: [CleanedItem] = []
    var startedAt = Date()
    var finishedAt = Date()
    var freedBytes: Int64 = 0
    var skippedCount: Int = 0
    var failedCount: Int = 0
    var usedTrash: Bool = false
    var freeBefore: Int64 = 0
    var freeAfter: Int64 = 0
}