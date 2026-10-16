import SwiftUI

@main
struct DiskCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu(Text(L.string("menu.actions"))) {
                Button(L.string("menu.rescan")) {
                    appState.rescan()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.phase != .report)

                Button(L.string("menu.export")) {
                    appState.exportReport()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.phase != .report)

                Button(L.string("menu.clean")) {
                    appState.requestCleanup()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(appState.phase != .report)
            }
        }
    }
}