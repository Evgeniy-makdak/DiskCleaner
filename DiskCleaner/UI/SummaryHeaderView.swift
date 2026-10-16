import SwiftUI

struct SummaryHeaderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let result = appState.scanResult {
            HStack(spacing: 28) {
                stat(L.string("summary.used"), Formatters.byteCount(result.systemInfo.diskTotalBytes - result.systemInfo.diskFreeBytes), color: .primary)
                stat(L.string("summary.free"), Formatters.byteCount(result.systemInfo.diskFreeBytes), color: .blue)
                stat(L.string("summary.junk"), Formatters.byteCount(result.junkBytes), color: .green)
                if let surprise = result.biggestSurprise {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.string("summary.surprise"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(surprise.displaySize) — \(surprise.displayPath)")
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func stat(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}