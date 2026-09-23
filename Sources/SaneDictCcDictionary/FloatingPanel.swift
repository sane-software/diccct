import AppKit

/// A borderless, non-activating floating panel.
///
/// Borderless windows do not become key by default, but the search field must be
/// able to receive keyboard focus — so we override `canBecomeKey`. Being a
/// `.nonactivatingPanel` at `.floating` level means it can take key focus and
/// stay above other windows *without* activating SaneDictCcDictionary as the foreground app, so
/// clicking another window never sends this panel behind it.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
