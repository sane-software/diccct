import AppKit
import SwiftUI

/// Owns the app window: a single floating panel pinned to the top-right corner
/// of a screen.
///
/// Window behaviour:
/// - Always pinned to the top-right of its current screen. Position is never
///   persisted (only size is) — it is always derived.
/// - Draggable (via the window background / top padding). A drag only serves to
///   move it to another screen: on release it snaps back to the top-right of
///   whichever screen it now sits on. You cannot freely reposition it within a
///   screen.
/// - Resizable; the size is persisted across launches. After a resize it re-pins
///   so the top-right stays anchored.
/// - Resilient to screen changes (external monitor plugged/unplugged): re-pins to
///   the current screen and shrinks to fit if the saved size no longer fits.
final class PanelController: NSObject, NSWindowDelegate {
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

    /// True while we move/resize the panel ourselves, so our own frame changes
    /// don't get mistaken for a user drag.
    private var isAdjusting = false
    private var snapWorkItem: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    /// Called just before the panel is shown — used to focus the search field.
    var onWillShow: (() -> Void)?

    init(rootView: @escaping () -> AnyView) {
        self.rootView = rootView
        super.init()

        // Re-pin (and shrink to fit) when the screen layout changes.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                self.pinTopRight(panel)
            }
        }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        let panel = ensurePanel()
        pinTopRight(panel)
        onWillShow?()
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
            // Titled (utility) rather than borderless so the window gets macOS's
            // default rounded corners — matching the SaneWindowList app, whose
            // rounding is likewise the system default, not a custom radius. The
            // titlebar is emptied and made transparent so it reads as a thin top
            // grab strip, and the standard window buttons are hidden.
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.titlebarSeparatorStyle = .none
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        // Visible across spaces and over full-screen apps, so it stays reachable.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Draggable by the empty titlebar strip and window background; interactive
        // controls and selectable text are not affected.
        panel.isMovableByWindowBackground = true
        panel.minSize = minSize
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.delegate = self

        let hosting = NSHostingView(rootView: rootView())
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = hosting

        self.panel = panel
        return panel
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        // Ignore frame changes we made ourselves; only react to user drags.
        guard !isAdjusting else { return }
        // Debounce: snap once the drag settles (i.e. after the user releases),
        // rather than fighting the pointer mid-drag.
        snapWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }
            self.pinTopRight(panel)
        }
        snapWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel else { return }
        saveSize(panel.frame.size)
        // Keep the top-right corner anchored after a resize.
        pinTopRight(panel)
    }

    // MARK: - Positioning

    /// Pin the panel to the top-right of its current screen, shrinking it to fit
    /// if the size is too large for that screen.
    private func pinTopRight(_ panel: NSPanel) {
        let visible = targetScreen(for: panel).visibleFrame

        var frame = panel.frame
        frame.size.width = min(frame.size.width, visible.width - screenMargin * 2)
        frame.size.height = min(frame.size.height, visible.height - screenMargin * 2)
        frame.origin.x = visible.maxX - frame.size.width - screenMargin
        frame.origin.y = visible.maxY - frame.size.height - screenMargin

        isAdjusting = true
        panel.setFrame(frame, display: true)
        isAdjusting = false
    }

    /// The screen the panel most overlaps (where the user dragged it), falling
    /// back to the main screen — which is also the first-launch default, since the
    /// initial frame sits at the origin of the main screen's coordinate space.
    private func targetScreen(for panel: NSPanel) -> NSScreen {
        let frame = panel.frame
        let best = NSScreen.screens.max { lhs, rhs in
            overlapArea(frame, lhs.frame) < overlapArea(frame, rhs.frame)
        }
        if let best, overlapArea(frame, best.frame) > 0 { return best }
        return NSScreen.main ?? NSScreen.screens.first ?? best!
    }

    private func overlapArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    // MARK: - Size persistence

    private func savedSize() -> NSSize {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: Defaults.width)
        let height = defaults.double(forKey: Defaults.height)
        guard width > 0, height > 0 else { return defaultSize }
        return NSSize(width: max(width, minSize.width), height: max(height, minSize.height))
    }

    private func saveSize(_ size: NSSize) {
        let defaults = UserDefaults.standard
        defaults.set(Double(size.width), forKey: Defaults.width)
        defaults.set(Double(size.height), forKey: Defaults.height)
    }
}
