import SwiftUI

struct CleaningView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            if let report = appState.finalCleaningReport {
                finalReport(report)
            } else {
                ProgressView()
                    .controlSize(.large)
                Text(L.string("clean.inProgress"))
                    .font(.headline)
                List(appState.cleaningItems) { item in
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon(item.result))
                            .foregroundStyle(statusColor(item.result))
                        Text(item.item.displayPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(item.message)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                .frame(maxWidth: 700, maxHeight: 300)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func finalReport(_ report: CleaningReport) -> some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(.green)
        Text(L.string("clean.done"))
            .font(.title2.bold())
        Text("\(L.string("clean.freed")) \(Formatters.byteCount(report.freedBytes))")
            .font(.title3.monospacedDigit())

        if !report.items.isEmpty {
            List(report.items) { item in
                HStack(spacing: 8) {
                    Image(systemName: statusIcon(item.result))
                        .foregroundStyle(statusColor(item.result))
                    Text(item.item.displayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(item.message)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            .frame(maxWidth: 700, maxHeight: 220)
        }

        let snapshotCount = appState.scanResult?.systemInfo.localSnapshots.count ?? 0
        if snapshotCount > 0 {
            Text("\(L.string("clean.snapshots")) \(snapshotCount) \(L.string("clean.snapshots2"))")
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        HStack(spacing: 12) {
            Button(L.string("clean.restart")) {
                restartNow()
            }
            .buttonStyle(.borderedProminent)
            Button(L.string("clean.later")) {
                appState.phase = .report
            }
        }
    }

    private func statusIcon(_ result: CleanResult) -> String {
        switch result {
        case .success: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .failed: return "xmark.octagon.fill"
        case .requiresManual: return "hand.raised.fill"
        }
    }

    private func statusColor(_ result: CleanResult) -> Color {
        switch result {
        case .success: return .green
        case .skipped: return .gray
        case .failed: return .red
        case .requiresManual: return .orange
        }
    }

    private func restartNow() {
        let r = CommandRunner.run(
            "/usr/bin/osascript",
            arguments: ["-e", "tell application \"System Events\" to restart"],
            timeout: 30
        )
        if r.exitCode != 0 {
            appState.errorMessage = r.stderr
        }
    }
}