import AppKit

// Entry point. SaneDiccct is a menu-bar-only agent: no Dock icon, no main menu bar.
// Setting the activation policy to .accessory here (rather than relying on an
// Info.plist LSUIElement key) means the app behaves correctly whether launched
// from the assembled SaneDiccct.app bundle or directly via `swift run`.
//
// Top-level code in main.swift is nonisolated, but it always runs on the main
// thread, so we assert main-actor isolation to construct the (main-actor) app
// delegate. `delegate` is a global, so it lives for the process lifetime (an
// NSApplication delegate is held weakly).
let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
