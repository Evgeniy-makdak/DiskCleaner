import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "didShowFDAHint") {
            defaults.set(true, forKey: "didShowFDAHint")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showFDAAlert()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func showFDAAlert() {
        let alert = NSAlert()
        alert.messageText = L.string("fda.title")
        alert.informativeText = L.string("fda.message")
        alert.addButton(withTitle: L.string("fda.open"))
        alert.addButton(withTitle: L.string("fda.later"))
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}