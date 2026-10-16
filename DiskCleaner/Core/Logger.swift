import Foundation
import CryptoKit

struct LogEntry: Codable {
    var timestamp: Date
    var action: String
    var path: String
    var sizeBytes: Int64
    var sha256: String?
    var approvedBy: String
    var result: String
    var usedTrash: Bool
}

/// Пишет все действия в JSON-лог в
/// `~/Library/Application Support/DiskCleaner/logs/YYYY-MM-DD_HH-mm-ss.log`
/// и ошибки в `errors.log`.
final class Logger {
    static let shared = Logger()

    private let baseDir: URL
    private let logsDir: URL
    private let errorsURL: URL
    private let fileManager = FileManager.default

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("DiskCleaner", isDirectory: true)
        logsDir = baseDir.appendingPathComponent("logs", isDirectory: true)
        errorsURL = baseDir.appendingPathComponent("errors.log")
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    var currentLogURL: URL {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return logsDir.appendingPathComponent("\(df.string(from: Date())).log")
    }

    func logAction(_ entry: LogEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entry) else { return }
        let url = currentLogURL
        if fileManager.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.write(Data("\n".utf8))
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    func logError(_ error: Error, context: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(context): \(error.localizedDescription)\n"
        if fileManager.fileExists(atPath: errorsURL.path) {
            guard let handle = try? FileHandle(forWritingTo: errorsURL) else { return }
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: errorsURL)
        }
    }

    /// SHA-256 файла. Хешируем только файлы до 100 МБ —
    /// хеширование гигабайтов слишком долго для снимка действия.
    static func sha256(ofFile path: String) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = (attrs[.size] as? NSNumber)?.int64Value,
              size < 100 * 1024 * 1024,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}