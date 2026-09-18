import AppKit

// Entry point. Diccct is a menu-bar-only agent: no Dock icon, no main menu bar.
// Setting the activation policy to .accessory here (rather than relying on an
// Info.plist LSUIElement key) means the app behaves correctly whether launched
// from the assembled Diccct.app bundle or directly via `swift run`.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
