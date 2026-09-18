import AppKit
import SwiftUI

/// Manages the menu-bar status item and routes its clicks:
/// - left click  -> toggle the app window open/closed
/// - right click (or control-click) -> context menu with Quit
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController: PanelController

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panelController = PanelController(rootView: { AnyView(PlaceholderView()) })
        super.init()

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.toolTip = "Diccct"
            button.target = self
            button.action = #selector(handleClick)
            // Receive both mouse buttons on the same action so we can branch.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
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
        let quit = NSMenuItem(title: "Quit Diccct", action: #selector(quit), keyEquivalent: "q")
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
