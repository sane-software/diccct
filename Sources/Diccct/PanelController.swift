import AppKit
import SwiftUI

/// Owns the app window: a single floating panel pinned to the top-right corner
/// of the screen. Creating it lazily on first show keeps launch cheap.
///
/// This commit establishes create / toggle / top-right positioning with a
/// persisted size. Drag-to-move-between-screens, screen-change re-pinning and
/// resize persistence are layered on in a later step.
final class PanelController: NSObject {
    private var panel: FloatingPanel?
    private let rootView: () -> AnyView

    // Persisted window size (position is always derived: top-right).
    private enum Defaults {
        static let width = "panelWidth"
        static let height = "panelHeight"
    }
    private let defaultSize = NSSize(width: 440, height: 380)
    private let minSize = NSSize(width: 340, height: 220)
    private let screenMargin: CGFloat = 8

    init(rootView: @escaping () -> AnyView) {
        self.rootView = rootView
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        let panel = ensurePanel()
        pinTopRight(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Panel construction

    private func ensurePanel() -> FloatingPanel {
        if let panel { return panel }

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: savedSize()),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        // Visible across spaces and over full-screen apps, so it stays reachable.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.minSize = minSize
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor

        let hosting = NSHostingView(rootView: rootView())
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = hosting

        self.panel = panel
        return panel
    }

    // MARK: - Positioning

    /// Pin the panel to the top-right of its current screen (main screen the
    /// first time), shrinking it to fit if the saved size is too large.
    private func pinTopRight(_ panel: NSPanel) {
        let screen = panel.isVisible ? (panel.screen ?? .main) : .main
        guard let visible = (screen ?? NSScreen.screens.first)?.visibleFrame else { return }

        var frame = panel.frame
        frame.size.width = min(frame.size.width, visible.width - screenMargin * 2)
        frame.size.height = min(frame.size.height, visible.height - screenMargin * 2)
        frame.origin.x = visible.maxX - frame.size.width - screenMargin
        frame.origin.y = visible.maxY - frame.size.height - screenMargin
        panel.setFrame(frame, display: true)
    }

    // MARK: - Size persistence

    private func savedSize() -> NSSize {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: Defaults.width)
        let height = defaults.double(forKey: Defaults.height)
        guard width > 0, height > 0 else { return defaultSize }
        return NSSize(width: max(width, minSize.width), height: max(height, minSize.height))
    }
}
