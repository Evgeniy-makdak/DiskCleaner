import SwiftUI

struct UserDataTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\ScanItem.sizeBytes, order: .reverse)]

    private var items: [ScanItem] { appState.scanResult?.userDataItems ?? [] }
    private var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(spacing: 8) {
            Label(L.string("userData.warning"), systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Toggle(L.string("selectAll"), isOn: Binding(
                    get: { !items.isEmpty && items.allSatisfy(\.isSelected) },
                    set: { appState.setAllSelected(in: .userData, to: $0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("\(L.string("cleanSelected")) (\(Formatters.byteCount(selectedBytes)))") {
                    appState.requestCleanup()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(selectedBytes == 0)
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
            }
            .tableStyle(.inset)
        }
    }
}