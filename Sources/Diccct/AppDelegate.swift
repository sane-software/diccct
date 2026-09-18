import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Owns the menu-bar status item and, through it, the app window. Held for
    /// the lifetime of the app.
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
    }
}
