import Foundation
import DiccctCore

/// Observable state bridging DiccctCore to the SwiftUI views.
///
/// Memory model (per the app design): only the *selected* pair is held in RAM.
/// On launch the directory is scanned once; the first pair (deterministic order)
/// becomes active and is loaded. Switching pairs purges the previous index and
/// loads the newly selected one. Nothing about the selection is persisted across
/// restarts.
@MainActor
final class AppModel: ObservableObject {
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
    /// Incremented to ask the view to focus (and select) the search field.
    @Published private(set) var focusRequest: Int = 0
    /// Set when an import fails, for the view to surface as an alert.
    @Published var importErrorMessage: String?

    /// At most this many result rows are shown.
    let resultLimit = 50

    /// Invoked by the minimize button; wired to hide the panel.
    var onRequestClose: (() -> Void)?

    private let dataDirectory: DataDirectory
    private var fileURLsByPair: [LanguagePair: URL] = [:]
    /// Search index for the active pair only (nil while none loaded / loading).
    private var index: TranslationIndex?
    /// Guards against a slow load for a pair the user has since switched away from.
    private var loadToken = 0

    init(dataDirectory: DataDirectory = .standard()) {
        self.dataDirectory = dataDirectory
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

    /// Run the search for the current query text. Called on Enter only. An empty
    /// query clears the results.
    func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index else {
            results = []
            return
        }
        results = index.search(trimmed, limit: resultLimit)
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

    /// Ask the view to focus (and select) the search field, e.g. on panel show.
    func requestFocus() {
        focusRequest += 1
    }
}
