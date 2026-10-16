import SwiftUI

struct HistoryTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\ScanItem.sizeBytes, order: .reverse)]

    private var items: [ScanItem] { appState.scanResult?.historyItems ?? [] }

    var body: some View {
        VStack(spacing: 8) {
            Label(L.string("history.warning"), systemImage: "lock.shield.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .padding(.horizontal)

            Table(items, sortOrder: $sortOrder) {
                TableColumn(Text(L.string("col.size")), value: \.sizeBytes) { item in
                    Text(item.displaySize).monospacedDigit()
                }
                .width(90)
                TableColumn(Text(L.string("col.path")), value: \.path) { item in
                    Text(item.displayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(item.path)
                }
                TableColumn(Text(L.string("col.kind")), value: \.kind) { item in
                    Text(item.kind)
                }
            }
            .tableStyle(.inset)
        }
    }
}