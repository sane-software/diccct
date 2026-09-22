import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Owns the menu-bar status item and, through it, the app window. Held for
    /// the lifetime of the app.
    private var statusItemController: StatusItemController?
    /// The shared app model; also the target of the Undo/Redo menu shortcuts.
    private let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItemController = StatusItemController(model: model)
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
        // Cmd+M hides the window (our "minimize"), same as the minus button and
        // clicking the menu-bar icon. Targets the model explicitly so it works
        // while the search field is the first responder.
        let minimizeItem = NSMenuItem(title: "Minimize",
                                      action: #selector(AppModel.minimizeWindow(_:)),
                                      keyEquivalent: "m")
        minimizeItem.target = model
        appMenu.addItem(minimizeItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit SaneDiccct",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        // Undo/Redo drive the search history (not text-field editing undo). They
        // target the model explicitly, so Cmd+Z / Cmd+Shift+Z work even while the
        // search field is the first responder.
        let undoItem = NSMenuItem(title: "Undo Search", action: #selector(AppModel.undoSearch(_:)), keyEquivalent: "z")
        undoItem.target = model
        editMenu.addItem(undoItem)
        let redoItem = NSMenuItem(title: "Redo Search", action: #selector(AppModel.redoSearch(_:)), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = model
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
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
