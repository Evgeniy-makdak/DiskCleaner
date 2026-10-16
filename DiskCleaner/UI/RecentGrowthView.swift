import SwiftUI

struct RecentGrowthView: View {
    @EnvironmentObject var appState: AppState

    private var items: [ScanItem] { appState.scanResult?.recentGrowth ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.string("recent.title"))
                .font(.headline)
            if items.isEmpty {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Text(item.displaySize)
                            .font(.callout.monospacedDigit())
                            .frame(width: 80, alignment: .trailing)
                        Text(item.displayPath)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(item.path)
                        Spacer()
                        Text(Formatters.shortDate(item.modifiedDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }
}