import SwiftUI
import AppKit

struct ConfirmationSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var useTrash = true
    @State private var confirmed = false

    private var items: [ScanItem] { appState.pendingCleanup }
    private var sudoItems: [ScanItem] { items.filter(\.requiresPrivileges) }
    private var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.string("confirm.title"))
                .font(.title2.bold())
            Text("\(L.string("confirm.subtitle")) \(Formatters.byteCount(totalBytes))")
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: item))
                                .foregroundStyle(color(for: item))
                            Text(item.displayPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(item.path)
                            Spacer()
                            Text(item.displaySize)
                                .monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
            }
            .frame(maxHeight: 280)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))

            if !sudoItems.isEmpty {
                Label(L.string("confirm.sudo"), systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if let warning = runningAppsWarning() {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            Toggle(L.string("confirm.useTrash"), isOn: $useTrash)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("useTrashToggle")

            Toggle(L.string("confirm.understand"), isOn: $confirmed)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("understandToggle")

            HStack {
                Button(L.string("confirm.cancel")) {
                    dismiss()
                }
                .accessibilityIdentifier("cancelCleanupButton")
                Spacer()
                Button(L.string("confirm.delete")) {
                    appState.confirmCleanup(useTrash: useTrash)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!confirmed)
                .accessibilityIdentifier("confirmDeleteButton")
            }
        }
        .padding(24)
        .frame(width: 660)
    }

    private func icon(for item: ScanItem) -> String {
        switch item.action {
        case .brctlEvict: return "icloud.and.arrow.up"
        case .npmCacheClean, .pnpmStorePrune, .yarnCacheClean, .cargoCacheAutoclean: return "shippingbox"
        case .manual: return "lock"
        case .removeItem, .trashItem: return "trash"
        }
    }

    private func color(for item: ScanItem) -> Color {
        switch item.category {
        case .junk: return .green
        case .userData: return .orange
        case .history: return .red
        }
    }

    /// Предупреждение о запущенных приложениях, чьи файлы будут удалены.
    private func runningAppsWarning() -> String? {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.localizedName })
        let targets = ["Google Chrome", "Safari", "Firefox", "Xcode", "Visual Studio Code", "Cursor", "Slack", "Discord", "Telegram", "Figma"]
        let hit = targets.filter { running.contains($0) }
        guard !hit.isEmpty else { return nil }
        return L.string("confirm.runningApps") + " " + hit.joined(separator: ", ")
    }
}