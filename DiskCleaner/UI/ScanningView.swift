import SwiftUI

struct ScanningView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView(value: appState.scanProgress.fraction)
                .progressViewStyle(.linear)
                .frame(maxWidth: 520)
            Text(appState.scanProgress.currentStep)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("\(L.string("scan.found")) \(Formatters.byteCount(appState.scanProgress.foundBytes))")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(L.string("scan.cancel")) {
                appState.cancelScan()
            }
            .accessibilityIdentifier("cancelScanButton")
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}