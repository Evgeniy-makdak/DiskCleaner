import Foundation

/// Собирает информацию о системе: версия macOS, архитектура, место на диске,
/// состояние APFS, локальные снапшоты Time Machine. Только чтение.
struct SystemProbe {
    static func collect() -> SystemInfo {
        var info = SystemInfo()
        info.osVersion = CommandRunner.run("/usr/bin/sw_vers", arguments: ["-productVersion"]).stdout.trimmed
        info.architecture = CommandRunner.run("/usr/bin/uname", arguments: ["-m"]).stdout.trimmed
        info.diskTotalBytes = DiskSpace.totalBytes()
        info.diskFreeBytes = DiskSpace.freeBytes()

        let apfs = CommandRunner.run("/usr/sbin/diskutil", arguments: ["apfs", "list"], timeout: 60)
        info.apfsSummary = summarizeAPFS(apfs.stdout)

        let snaps = CommandRunner.run("/usr/bin/tmutil", arguments: ["listlocalsnapshots", "/"], timeout: 60)
        info.localSnapshots = parseSnapshots(snaps.stdout)
        return info
    }

    private static func summarizeAPFS(_ output: String) -> String {
        var lines: [String] = []
        for line in output.split(separator: "\n") {
            let l = String(line)
            if l.contains("Container") || l.contains("Capacity") || l.contains("Allocated") || l.contains("Snapshots") {
                lines.append(l.trimmingCharacters(in: .whitespaces))
            }
        }
        return lines.prefix(12).joined(separator: "\n")
    }

    private static func parseSnapshots(_ output: String) -> [String] {
        output.split(separator: "\n").map(String.init).filter { $0.contains("com.apple.TimeMachine") }
    }
}