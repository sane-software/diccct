import AppKit
import SwiftUI

/// Manages the menu-bar status item and routes its clicks:
/// - left click  -> toggle the app window open/closed
/// - right click (or control-click) -> context menu with Quit
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController: PanelController
    private let model: AppModel

    init(model: AppModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.model = model
        panelController = PanelController(rootView: { AnyView(ContentView(model: model)) })
        super.init()

        // Minimize button hides the window, same as clicking the menu-bar icon.
        model.onRequestClose = { [weak self] in self?.panelController.hide() }
        // Focus the search field whenever the window is shown.
        panelController.onWillShow = { [weak self] in self?.model.requestFocus() }

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.toolTip = "SaneDiccct"
            button.target = self
            button.action = #selector(handleClick)
            // Receive both mouse buttons on the same action so we can branch.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.loadOnLaunch()
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else {
            panelController.toggle()
            return
        }
        let isRightClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isRightClick {
            showContextMenu()
        } else {
            panelController.toggle()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit SaneDiccct", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Attaching the menu and re-clicking pops it under the status item; clear
        // it again afterwards so a plain left-click keeps toggling the window.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
