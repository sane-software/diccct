import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Owns the menu-bar status item and, through it, the app window. Held for
    /// the lifetime of the app.
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItemController = StatusItemController()
    }

    /// Accessory apps show no menu bar, but the main menu is still what routes the
    /// standard editing shortcuts (⌘X/⌘C/⌘V/⌘A) to the key window's first responder
    /// via menu key equivalents. Without it only the right-click "Copy" works. A
    /// minimal Edit menu makes the shortcuts work in the search field and in
    /// selected result text. Items have a nil target, so they dispatch down the
    /// responder chain to whatever currently handles the selection.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Diccct",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
