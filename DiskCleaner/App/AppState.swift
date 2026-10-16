import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Потокобезопасный флаг отмены сканирования.
final class ScanCancellation {
    private let lock = NSLock()
    private var _cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        _cancelled = true
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case welcome
        case scanning
        case report
        case cleaning
    }

    @Published var phase: Phase = .welcome
    @Published var scanProgress = ScanProgress()
    @Published var scanResult: ScanResult?
    @Published var cleaningItems: [CleanedItem] = []
    @Published var finalCleaningReport: CleaningReport?
    @Published var isConfirmationPresented = false
    @Published var pendingCleanup: [ScanItem] = []
    @Published var errorMessage: String?

    private var cancellation = ScanCancellation()

    // MARK: - Сканирование

    func startScan() {
        cancellation = ScanCancellation()
        phase = .scanning
        scanProgress = ScanProgress(isRunning: true)
        let token = cancellation
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let scanner = Scanner()
            let result = scanner.scan(shouldCancel: { token.isCancelled }) { p in
                Task { @MainActor in
                    self.scanProgress = p
                }
            }
            await MainActor.run {
                guard !token.isCancelled else { return }
                self.scanResult = result
                self.phase = .report
            }
        }
    }

    func scanFolder(_ url: URL) {
        cancellation = ScanCancellation()
        phase = .scanning
        scanProgress = ScanProgress(isRunning: true)
        let token = cancellation
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let scanner = Scanner()
            let result = scanner.scanFolder(url, shouldCancel: { token.isCancelled }) { p in
                Task { @MainActor in
                    self.scanProgress = p
                }
            }
            await MainActor.run {
                guard !token.isCancelled else { return }
                self.scanResult = result
                self.phase = .report
            }
        }
    }

    func rescan() {
        guard phase == .report else { return }
        startScan()
    }

    func cancelScan() {
        cancellation.cancel()
        phase = .welcome
    }

    // MARK: - Выбор элементов

    func setSelected(_ item: ScanItem, to value: Bool) {
        guard var result = scanResult,
              let idx = result.items.firstIndex(where: { $0.id == item.id }) else { return }
        result.items[idx].isSelected = value
        scanResult = result
    }

    func setAllSelected(in category: ScanCategory, to value: Bool) {
        guard var result = scanResult else { return }
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = value
        }
        scanResult = result
    }

    // MARK: - Очистка

    func requestCleanup() {
        guard let result = scanResult else { return }
        let selected = result.items.filter { $0.isSelected && $0.category != .history }
        guard !selected.isEmpty else { return }
        pendingCleanup = selected
        isConfirmationPresented = true
    }

    func confirmCleanup(useTrash: Bool) {
        isConfirmationPresented = false
        phase = .cleaning
        cleaningItems = []
        finalCleaningReport = nil
        let items = pendingCleanup
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let cleaner = Cleaner()
            let report = cleaner.clean(items: items, useTrash: useTrash) { cleaned in
                Task { @MainActor in
                    self.cleaningItems.append(cleaned)
                }
            }
            await MainActor.run {
                self.finalCleaningReport = report
            }
        }
    }

    // MARK: - Экспорт

    func exportReport() {
        guard let result = scanResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "DiskCleaner-report.md"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try Reporter.markdownReport(from: result).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Права

    func requestFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}