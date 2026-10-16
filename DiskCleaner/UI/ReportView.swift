import SwiftUI

struct ReportView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            SummaryHeaderView()

            if let result = appState.scanResult, !result.errors.isEmpty {
                errorsSection(result.errors)
            }

            Picker("", selection: $selectedTab) {
                Text(L.string("tab.junk")).tag(0)
                Text(L.string("tab.userData")).tag(1)
                Text(L.string("tab.history")).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case 0: JunkTabView()
            case 1: UserDataTabView()
            default: HistoryTabView()
            }

            RecentGrowthView()
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func errorsSection(_ errors: [ScanError]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(errors) { error in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(error.command): \(error.message)")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if error.requiresPrivileges {
                        Button(L.string("errors.request")) {
                            appState.requestFullDiskAccess()
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}