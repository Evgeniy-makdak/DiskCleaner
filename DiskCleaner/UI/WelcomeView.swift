import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text(L.string("app.name"))
                .font(.largeTitle.bold())
            Text(L.string("welcome.warning"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .foregroundStyle(.secondary)
            Button {
                appState.startScan()
            } label: {
                Label(L.string("welcome.start"), systemImage: "play.fill")
                    .font(.title3)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("startScanButton")

            Spacer()

            VStack(spacing: 8) {
                Text(L.string("welcome.dragHint"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(width: 380, height: 80)
                    .overlay(
                        Text(L.string("welcome.dropZone"))
                            .foregroundStyle(.secondary)
                    )
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            appState.scanFolder(url)
                        }
                    }
                }
                return true
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}