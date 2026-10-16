import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .welcome:
                WelcomeView()
            case .scanning:
                ScanningView()
            case .report:
                ReportView()
            case .cleaning:
                CleaningView()
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .sheet(isPresented: $appState.isConfirmationPresented) {
            ConfirmationSheet()
        }
        .alert(
            L.string("errors.title"),
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )
        ) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}