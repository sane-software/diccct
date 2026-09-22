import Foundation
import AppKit
import SaneDiccctCore

/// Observable state bridging SaneDiccctCore to the SwiftUI views.
///
/// Memory model (per the app design): only the *selected* pair is held in RAM.
/// On launch the directory is scanned once; the first pair (deterministic order)
/// becomes active and is loaded. Switching pairs purges the previous index and
/// loads the newly selected one. Nothing about the selection is persisted across
/// restarts.
///
/// It is an NSObject so it can be the target of the Undo/Redo menu items (the
/// Cmd+Z / Cmd+Shift+Z shortcuts), which drive the search history below.
@MainActor
final class AppModel: NSObject, ObservableObject, NSMenuItemValidation {
    /// All pairs found in the data directory, in dropdown order.
    @Published private(set) var availablePairs: [LanguagePair] = []
    /// The active pair, or nil when nothing is loaded yet.
    @Published private(set) var selectedPair: LanguagePair?
    /// Live search-field text. Editing it does NOT search; only Enter does.
    @Published var query: String = ""
    /// Results of the last committed search.
    @Published private(set) var results: [TranslationEntry] = []
    /// True while a pair's file is being parsed into memory.
    @Published private(set) var isLoading: Bool = false
    /// Incremented to ask the view to focus the search field (caret at the end).
    @Published private(set) var focusRequest: Int = 0
    /// Set when an import fails, for the view to surface as an alert.
    @Published var importErrorMessage: String?

    /// At most this many result rows are shown.
    let resultLimit = 50

    /// Whether undo / redo are currently available (drives the buttons + menu).
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    /// Invoked by the minimize button; wired to hide the panel.
    var onRequestClose: (() -> Void)?

    private let dataDirectory: DataDirectory
    private var fileURLsByPair: [LanguagePair: URL] = [:]
    /// Search index for the active pair only (nil while none loaded / loading).
    private var index: TranslationIndex?
    /// Guards against a slow load for a pair the user has since switched away from.
    private var loadToken = 0

    /// Search history for undo/redo; not persisted across restarts.
    private var searchHistory = SearchHistory(capacity: 50)

    init(dataDirectory: DataDirectory = .standard()) {
        self.dataDirectory = dataDirectory
        super.init()
    }

    var hasPairs: Bool { !availablePairs.isEmpty }

    // MARK: - Launch

    /// Scan the data directory once and activate the first available pair.
    func loadOnLaunch() {
        // Best-effort: if the directory can't be created the scan simply finds
        // nothing and the UI shows its empty state, which is informative rather
        // than a hard crash on launch.
        _ = try? dataDirectory.ensureExists()
        refreshAvailablePairs()
        if let first = availablePairs.first {
            activate(first)
        }
    }

    private func refreshAvailablePairs() {
        let datasets = dataDirectory.availableDatasets()
        fileURLsByPair = Dictionary(uniqueKeysWithValues: datasets.map { ($0.pair, $0.fileURL) })
        availablePairs = datasets.map(\.pair)
    }

    // MARK: - Pair selection

    /// Select a pair from the dropdown. Purges the old index and loads the new
    /// one; clears the shown results but keeps the query text (user presses Enter
    /// to search the new pair).
    func select(_ pair: LanguagePair) {
        guard pair != selectedPair else { return }
        activate(pair)
    }

    private func activate(_ pair: LanguagePair) {
        guard let url = fileURLsByPair[pair] else { return }
        selectedPair = pair
        results = []
        index = nil
        isLoading = true

        loadToken += 1
        let token = loadToken
        Task.detached(priority: .userInitiated) {
            let entries = (try? DictccParser.parseEntries(atPath: url.path, pair: pair)) ?? []
            let newIndex = TranslationIndex(entries: entries)
            await MainActor.run {
                // Ignore if the user switched pairs while this was loading.
                guard token == self.loadToken else { return }
                self.index = newIndex
                self.isLoading = false
            }
        }
    }

    // MARK: - Search

    /// Execute the search for the current query text. An empty query clears the
    /// results. This is the raw executor; user submissions go through
    /// `submitFromUser()` so they also update the history.
    func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index else {
            results = []
            return
        }
        results = index.search(trimmed, limit: resultLimit)
    }

    /// A user-initiated search (typed + Enter): record it in the history, then run
    /// it.
    func submitFromUser() {
        searchHistory.record(query.trimmingCharacters(in: .whitespacesAndNewlines))
        refreshUndoRedoState()
        runSearch()
    }

    // MARK: - Search history (undo / redo)

    /// Load and run the previous search in the history.
    func undo() {
        guard let text = searchHistory.undo() else { return }
        loadHistoryAndRun(text)
    }

    /// Load and run the next search, or clear the field when moving past the newest.
    func redo() {
        guard let text = searchHistory.redo() else { return }
        loadHistoryAndRun(text)
    }

    private func loadHistoryAndRun(_ text: String) {
        query = text
        runSearch()
        refreshUndoRedoState()
        // Return focus to the field with the caret at the end (never selected).
        requestFocus()
    }

    private func refreshUndoRedoState() {
        canUndo = searchHistory.canUndo
        canRedo = searchHistory.canRedo
    }

    // Menu targets for the Cmd+Z / Cmd+Shift+Z shortcuts.
    @objc func undoSearch(_ sender: Any?) { undo() }
    @objc func redoSearch(_ sender: Any?) { redo() }

    /// Menu target for Cmd+M: hide the window, same as the minimize button.
    @objc func minimizeWindow(_ sender: Any?) { onRequestClose?() }

    nonisolated func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        MainActor.assumeIsolated {
            switch menuItem.action {
            case #selector(undoSearch(_:)): return canUndo
            case #selector(redoSearch(_:)): return canRedo
            default: return true
            }
        }
    }

    // MARK: - Import

    /// Import a dict.cc file, then activate the imported pair. Surfaces a
    /// message on failure (fail loud) instead of silently ignoring.
    func importFile(at url: URL) {
        do {
            let pair = try dataDirectory.importFile(from: url)
            refreshAvailablePairs()
            activate(pair)
        } catch DataDirectory.ImportError.notADictccFile {
            importErrorMessage = "That file is not a dict.cc vocabulary file (no valid header)."
        } catch {
            importErrorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Focus

    /// Ask the view to focus the search field (caret at the end, no selection),
    /// e.g. on panel show or after an undo/redo load.
    func requestFocus() {
        focusRequest += 1
    }
}
