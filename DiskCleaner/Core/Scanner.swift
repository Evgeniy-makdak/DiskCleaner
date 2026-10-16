import Foundation

/// Сканирует файловую систему ТОЛЬКО на чтение.
/// Никаких удалений здесь нет и быть не может.
struct Scanner {
    let home: String
    let fileManager: FileManager
    private let isFastScan: Bool

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.home = fileManager.homeDirectoryForCurrentUser.path
        // Режим для UI-тестов: пропускаем тяжёлые шаги.
        self.isFastScan = ProcessInfo.processInfo.environment["UITEST_FAST_SCAN"] == "1"
    }

    // MARK: - Полное сканирование

    func scan(shouldCancel: @escaping () -> Bool = { false },
              progress: @escaping (ScanProgress) -> Void) -> ScanResult {
        var findings: [RawFinding] = []
        var errors: [ScanError] = []
        let started = Date()
        let systemInfo = SystemProbe.collect()
        let totalSteps = isFastScan ? 5.0 : 17.0
        var step = 0.0

        func report(_ name: String) {
            step += 1
            let found = findings.reduce(Int64(0)) { $0 + $1.sizeBytes }
            progress(ScanProgress(
                currentStep: name,
                fraction: min(step / totalSteps, 1.0),
                foundBytes: found,
                isRunning: true
            ))
        }

        func add(_ newFindings: [RawFinding]) {
            findings.append(contentsOf: newFindings)
        }

        func cancelled() -> Bool {
            if shouldCancel() { return true }
            return false
        }

        // 1. Домашняя папка
        report(L.string("scan.home"))
        let homeResult = runDu(["-h", "-d", "1", home])
        if homeResult.requiresPrivileges {
            errors.append(ScanError(command: "du -d 1 ~", message: homeResult.stderr, requiresPrivileges: true))
        }
        add(parseDu(homeResult.stdout, source: .homeDu, skipRoot: home))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 2. Углубление в топ-10
        let top10 = findings.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(10)
        for dir in top10 {
            if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }
            report("\(L.string("scan.drill")) \(Formatters.displayPath(dir.path))")
            let r = runDu(["-h", "-d", "1", dir.path])
            add(parseDu(r.stdout, source: .homeDu, skipRoot: dir.path))
        }

        // 3. ~/Library
        report(L.string("scan.library"))
        let lib = "\(home)/Library"
        add(parseDu(runDu(["-h", "-d", "1", lib]).stdout, source: .libraryDu, skipRoot: lib))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 4. Application Support
        report(L.string("scan.appSupport"))
        let appSupport = "\(lib)/Application Support"
        add(parseDu(runDu(["-h", "-d", "1", appSupport]).stdout, source: .applicationSupportDu, skipRoot: appSupport))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 5. Caches
        report(L.string("scan.caches"))
        let caches = "\(lib)/Caches"
        add(parseDu(runDu(["-h", "-d", "1", caches]).stdout, source: .cachesDu, skipRoot: caches))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // Режим быстрого сканирования (UI-тесты): пропускаем тяжёлые шаги.
        if isFastScan {
            return ScanResult(
                items: Analyzer.classify(findings),
                systemInfo: systemInfo,
                errors: errors,
                startedAt: started,
                finishedAt: Date()
            )
        }

        // 6. CloudStorage
        report(L.string("scan.cloud"))
        let cloud = "\(lib)/CloudStorage"
        add(parseDu(runDu(["-h", "-d", "1", cloud]).stdout, source: .cloudStorageDu, skipRoot: cloud))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 7. Containers
        report(L.string("scan.containers"))
        let containers = "\(lib)/Containers"
        add(parseDu(runDu(["-h", "-d", "1", containers]).stdout, source: .containersDu, skipRoot: containers))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 8. Group Containers
        report(L.string("scan.groupContainers"))
        let groupContainers = "\(lib)/Group Containers"
        add(parseDu(runDu(["-h", "-d", "1", groupContainers]).stdout, source: .groupContainersDu, skipRoot: groupContainers))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 9. Системные папки
        report(L.string("scan.system"))
        let sysArgs = ["-xh", "-d", "1", "/Applications", "/Library", "/usr/local", "/opt", "/private/var"]
        let sysResult = CommandRunner.run("/usr/bin/du", arguments: sysArgs, timeout: 300)
        if sysResult.requiresPrivileges {
            errors.append(ScanError(command: "du -xh -d 1 /Applications /Library ...", message: sysResult.stderr, requiresPrivileges: true))
        }
        add(parseDu(sysResult.stdout, source: .systemDu, skipRoot: nil, skipRoots: ["/Applications", "/Library", "/usr/local", "/opt", "/private/var"]))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 10. code_sign_clone
        report(L.string("scan.codeSign"))
        let csResult = CommandRunner.run("/usr/bin/find", arguments: ["/private/var/folders", "-name", "*.code_sign_clone", "-maxdepth", "5"], timeout: 120)
        for path in csResult.stdout.split(separator: "\n") {
            let p = String(path)
            add([RawFinding(path: p, sizeBytes: fileSize(p), modifiedDate: fileDate(p), source: .codeSignClone, kindHint: "code_sign_clone")])
        }
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 11. Большие файлы
        report(L.string("scan.bigFiles"))
        let bigResult = CommandRunner.run("/usr/bin/find", arguments: [home, "-type", "f", "-size", "+200M", "-exec", "du", "-h", "{}", "+"], timeout: 300)
        add(parseDu(bigResult.stdout, source: .bigFiles, skipRoot: nil, withDates: true))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 12. state.vscdb (только просмотр — корзина history)
        report(L.string("scan.vscdb"))
        for app in ["Cursor", "Code"] {
            let base = "\(appSupport)/\(app)/User/globalStorage/state.vscdb"
            for p in [base, base + ".backup"] where fileManager.fileExists(atPath: p) {
                add([RawFinding(path: p, sizeBytes: fileSize(p), modifiedDate: fileDate(p), source: .vscdb, kindHint: "state.vscdb")])
            }
        }
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 13. Пакетные менеджеры
        report(L.string("scan.pkgManagers"))
        let npmCache = "\(home)/.npm/_cacache"
        let npx = "\(home)/.npm/_npx"
        let userCache = "\(home)/.cache"
        for p in [npmCache, npx, userCache] where fileManager.fileExists(atPath: p) {
            add([RawFinding(path: p, sizeBytes: dirSize(p), modifiedDate: fileDate(p), source: .packageManager, kindHint: "packageManager")])
        }
        let pnpmPath = CommandRunner.run("/usr/bin/sh", arguments: ["-lc", "pnpm store path 2>/dev/null"], timeout: 30).stdout.trimmed
        if !pnpmPath.isEmpty, fileManager.fileExists(atPath: pnpmPath) {
            add([RawFinding(path: pnpmPath, sizeBytes: dirSize(pnpmPath), modifiedDate: fileDate(pnpmPath), source: .packageManager, kindHint: "pnpm store")])
        }
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 14. Xcode
        report(L.string("scan.xcode"))
        let derived = "\(home)/Library/Developer/Xcode/DerivedData"
        let simulator = "\(home)/Library/Developer/CoreSimulator"
        for p in [derived, simulator] where fileManager.fileExists(atPath: p) {
            add([RawFinding(path: p, sizeBytes: dirSize(p), modifiedDate: fileDate(p), source: .xcode, kindHint: "xcode")])
        }
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 15. CloudStorage детально
        report(L.string("scan.cloudDetail"))
        let cloudDir = "\(lib)/CloudStorage"
        if let entries = try? fileManager.contentsOfDirectory(atPath: cloudDir) {
            for entry in entries {
                let p = "\(cloudDir)/\(entry)"
                add([RawFinding(path: p, sizeBytes: dirSize(p), modifiedDate: fileDate(p), source: .cloudStorageDu, kindHint: "iCloud")])
            }
        }
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 16. Недавно изменённые файлы
        report(L.string("scan.recent"))
        let recentResult = CommandRunner.run("/usr/bin/find", arguments: [home, "-type", "f", "-mtime", "-7", "-size", "+20M", "-exec", "du", "-h", "{}", "+"], timeout: 300)
        add(parseDu(recentResult.stdout, source: .bigFiles, skipRoot: nil, withDates: true))
        if cancelled() { return emptyResult(systemInfo: systemInfo, started: started) }

        // 17. Известные места мусора
        report(L.string("scan.knownJunk"))
        let knownJunkPaths = [
            "\(appSupport)/com.apple.wallpaper/aerials",
            "\(appSupport)/Google/GoogleUpdater/crx_cache",
            "\(appSupport)/Code/CachedExtensionVSIXs",
            "\(appSupport)/Code/CachedData",
            "\(appSupport)/Code/logs",
            "\(appSupport)/Code/Crashpad",
            "\(appSupport)/Code/agent-host/sdk-cache",
            "\(appSupport)/Cursor/snapshots",
            "\(appSupport)/Cursor/CachedData",
            "\(appSupport)/Cursor/logs",
            "\(appSupport)/Cursor/debugging-data",
            "\(lib)/HTTPStorages",
            "\(lib)/Caches/Homebrew",
        ]
        for p in knownJunkPaths where fileManager.fileExists(atPath: p) {
            add([RawFinding(path: p, sizeBytes: dirSize(p), modifiedDate: fileDate(p), source: .knownPath, kindHint: "knownJunk")])
        }

        return ScanResult(
            items: Analyzer.classify(findings),
            systemInfo: systemInfo,
            errors: errors,
            startedAt: started,
            finishedAt: Date()
        )
    }

    // MARK: - Сканирование одной папки (drag-and-drop)

    func scanFolder(_ url: URL,
                    shouldCancel: @escaping () -> Bool = { false },
                    progress: @escaping (ScanProgress) -> Void) -> ScanResult {
        var findings: [RawFinding] = []
        let path = url.path
        let systemInfo = SystemProbe.collect()

        progress(ScanProgress(currentStep: "\(L.string("scan.folder")) \(path)", fraction: 0.2, foundBytes: 0, isRunning: true))
        let r = runDu(["-h", "-d", "1", path])
        findings += parseDu(r.stdout, source: .dragAndDrop, skipRoot: path)

        let top10 = findings.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(10)
        for dir in top10 {
            if shouldCancel() { break }
            let rr = runDu(["-h", "-d", "1", dir.path])
            findings += parseDu(rr.stdout, source: .dragAndDrop, skipRoot: dir.path)
        }

        progress(ScanProgress(
            currentStep: L.string("scan.done"),
            fraction: 1.0,
            foundBytes: findings.reduce(0) { $0 + $1.sizeBytes },
            isRunning: false
        ))
        return ScanResult(
            items: Analyzer.classify(findings),
            systemInfo: systemInfo,
            errors: [],
            startedAt: Date(),
            finishedAt: Date()
        )
    }

    // MARK: - Helpers

    private func runDu(_ args: [String]) -> CommandResult {
        CommandRunner.run("/usr/bin/du", arguments: args, timeout: 300)
    }

    private func parseDu(_ output: String,
                         source: ScanSource,
                         skipRoot: String?,
                         skipRoots: [String] = [],
                         withDates: Bool = false) -> [RawFinding] {
        var result: [RawFinding] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let size = Formatters.parseSize(String(parts[0]))
            let path = String(parts[1])
            if let skip = skipRoot, path == skip { continue }
            if skipRoots.contains(path) { continue }
            if path == "/" { continue }
            result.append(RawFinding(
                path: path,
                sizeBytes: size,
                modifiedDate: withDates ? fileDate(path) : nil,
                source: source,
                kindHint: ""
            ))
        }
        return result
    }

    private func dirSize(_ path: String) -> Int64 {
        let r = CommandRunner.run("/usr/bin/du", arguments: ["-sk", path], timeout: 60)
        let line = r.stdout.split(separator: "\n").first.map(String.init) ?? ""
        let kb = line.split(separator: "\t").first.map(String.init) ?? "0"
        return (Int64(kb) ?? 0) * 1024
    }

    private func fileSize(_ path: String) -> Int64 {
        let attrs = try? fileManager.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func fileDate(_ path: String) -> Date? {
        let attrs = try? fileManager.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? Date
    }

    private func emptyResult(systemInfo: SystemInfo, started: Date) -> ScanResult {
        ScanResult(items: [], systemInfo: systemInfo, errors: [], startedAt: started, finishedAt: Date())
    }
}