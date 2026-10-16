import Foundation

/// Свободное и общее место на диске (только чтение).
enum DiskSpace {
    static func freeBytes() -> Int64 {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let v = values.volumeAvailableCapacityForImportantUsage {
            return v
        }
        let r = CommandRunner.run("/bin/df", arguments: ["-k", "/"], timeout: 30)
        return parseDf(r.stdout, column: 3) * 1024
    }

    static func totalBytes() -> Int64 {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]),
           let v = values.volumeTotalCapacity {
            return Int64(v)
        }
        let r = CommandRunner.run("/bin/df", arguments: ["-k", "/"], timeout: 30)
        return parseDf(r.stdout, column: 1) * 1024
    }

    /// df -k / → колонки: Filesystem 1024-blocks Used Available Capacity ...
    private static func parseDf(_ output: String, column: Int) -> Int64 {
        for line in output.split(separator: "\n").dropFirst() {
            let fields = line.split(separator: " ").map(String.init)
            if fields.count > column, let v = Int64(fields[column]) {
                return v
            }
        }
        return 0
    }
}