import Foundation

// MARK: - Categories

enum ScanCategory: String, Codable, CaseIterable, Identifiable {
    case junk
    case userData
    case history

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .junk: return L.string("category.junk")
        case .userData: return L.string("category.userData")
        case .history: return L.string("category.history")
        }
    }
}

// MARK: - Actions

enum CleanAction: String, Codable {
    case removeItem
    case trashItem
    case npmCacheClean
    case pnpmStorePrune
    case yarnCacheClean
    case cargoCacheAutoclean
    case brctlEvict
    case manual
}

// MARK: - Sources

enum ScanSource: String, Codable {
    case homeDu
    case libraryDu
    case applicationSupportDu
    case cachesDu
    case cloudStorageDu
    case containersDu
    case groupContainersDu
    case systemDu
    case codeSignClone
    case bigFiles
    case vscdb
    case packageManager
    case xcode
    case dragAndDrop
    case knownPath
}

// MARK: - Raw finding (before classification)

struct RawFinding {
    var path: String
    var sizeBytes: Int64
    var modifiedDate: Date?
    var source: ScanSource
    var kindHint: String
    var requiresPrivileges: Bool = false
}

// MARK: - Scan item

struct ScanItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var path: String
    var sizeBytes: Int64
    var category: ScanCategory
    var kind: String
    var freedImmediately: Bool
    var requiresPrivileges: Bool
    var isSelected: Bool
    var modifiedDate: Date?
    var source: ScanSource
    var action: CleanAction
    var note: String?

    var displaySize: String { Formatters.byteCount(sizeBytes) }
    var displayPath: String { Formatters.displayPath(path) }
}

// MARK: - String helpers

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}