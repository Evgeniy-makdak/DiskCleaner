import Foundation

enum Formatters {
    static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Парсит человекочитаемый размер из вывода `du -h` (например "1.4G", "512K", "0").
    static func parseSize(_ s: String) -> Int64 {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let last = t.last else { return 0 }
        let multipliers: [Character: Int64] = [
            "B": 1,
            "K": 1024,
            "M": 1024 * 1024,
            "G": 1024 * 1024 * 1024,
            "T": 1024 * 1024 * 1024 * 1024,
        ]
        if let m = multipliers[last], let num = Double(t.dropLast()) {
            return Int64(num * Double(m))
        }
        return Int64(Double(t) ?? 0)
    }
}