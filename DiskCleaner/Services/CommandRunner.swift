import Foundation

struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    /// Признак того, что команда упёрлась в права доступа (SIP/TCC/Full Disk Access).
    var requiresPrivileges: Bool {
        let s = (stdout + stderr).lowercased()
        return s.contains("operation not permitted")
            || s.contains("permission denied")
            || s.contains("not authorized")
    }
}

/// Запуск системных утилит через Process с таймаутом и безопасным чтением пайпов.
enum CommandRunner {
    @discardableResult
    static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 120) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return CommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }

        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        let group = DispatchGroup()
        var outString = ""
        var errString = ""

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outString = String(data: outHandle.readDataToEndOfFile(), encoding: .utf8) ?? ""
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errString = String(data: errHandle.readDataToEndOfFile(), encoding: .utf8) ?? ""
            group.leave()
        }

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            group.wait()
            return CommandResult(stdout: outString, stderr: "Timed out after \(Int(timeout))s", exitCode: -1)
        }
        group.wait()
        return CommandResult(stdout: outString, stderr: errString, exitCode: process.terminationStatus)
    }
}