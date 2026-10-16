import Foundation

/// Выполнение команд с правами администратора через osascript
/// (`do shell script ... with administrator privileges`).
/// Пароль запрашивается системой один раз; при отмене возвращается exitCode = -2.
enum PrivilegedHelper {
    static func runWithPrivileges(_ command: String) -> CommandResult {
        let script = "do shell script \(shellQuote(command)) with administrator privileges"
        let r = CommandRunner.run("/usr/bin/osascript", arguments: ["-e", script], timeout: 300)
        if r.stderr.contains("-128") || r.stderr.lowercased().contains("user canceled") {
            return CommandResult(stdout: r.stdout, stderr: "User canceled", exitCode: -2)
        }
        return r
    }

    static func shellQuote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}