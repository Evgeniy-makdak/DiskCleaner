import SwiftUI

struct JunkTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\ScanItem.sizeBytes, order: .reverse)]

    private var items: [ScanItem] { appState.scanResult?.junkItems ?? [] }
    private var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Toggle(L.string("selectAll"), isOn: Binding(
                    get: { !items.isEmpty && items.allSatisfy(\.isSelected) },
                    set: { appState.setAllSelected(in: .junk, to: $0) }
                ))
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("selectAllJunkToggle")
                Spacer()
                Button(L.string("exportMarkdown")) {
                    appState.exportReport()
                }
                .accessibilityIdentifier("exportReportButton")
                Button("\(L.string("cleanSelected")) (\(Formatters.byteCount(selectedBytes)))") {
                    appState.requestCleanup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBytes == 0)
                .accessibilityIdentifier("cleanSelectedButton")
            }
            .padding(.horizontal)

            Table(items, sortOrder: $sortOrder) {
                TableColumn(Text(L.string("col.select"))) { item in
                    Toggle("", isOn: Binding(
                        get: { item.isSelected },
                        set: { appState.setSelected(item, to: $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                }
                .width(36)
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
                TableColumn(Text(L.string("col.freed"))) { item in
                    Text(item.freedImmediately ? L.string("freed.now") : L.string("freed.afterReboot"))
                }
                .width(130)
            }
            .tableStyle(.inset)
        }
    }
}