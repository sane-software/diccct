import Foundation

/// Undo/redo history of search terms.
///
/// A list of past searches (oldest first) plus a cursor. The cursor ranges over
/// `0...entries.count`; when it equals `entries.count` the displayed state is the
/// cleared/empty field past the newest search.
///
/// Recording a *changed* search inserts it right after the current cursor,
/// preserving any entries that follow (the branch reached by undoing) instead of
/// discarding them. The history is capped by dropping the oldest entries.
public struct SearchHistory: Equatable, Sendable {
    private var entries: [String] = []
    private var position = 0
    public let capacity: Int

    public init(capacity: Int = 50) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
    }

    public var canUndo: Bool { position > 0 }
    public var canRedo: Bool { position < entries.count }

    /// The text shown at the current cursor; "" for the cleared/empty state.
    public var current: String { position < entries.count ? entries[position] : "" }

    /// Testing aid: the recorded entries, oldest first.
    public var storedEntries: [String] { entries }

    /// Record a user-committed search.
    ///
    /// - Unchanged from what's shown: no effect.
    /// - Empty: move to the cleared end state without adding an entry.
    /// - Otherwise: insert just after the current cursor (preserving following
    ///   entries) and move the cursor onto it; drop oldest entries beyond capacity.
    public mutating func record(_ text: String) {
        if text == current { return }

        if text.isEmpty {
            position = entries.count
            return
        }

        let insertionIndex = position < entries.count ? position + 1 : entries.count
        entries.insert(text, at: insertionIndex)
        position = insertionIndex

        while entries.count > capacity {
            entries.removeFirst()
            position -= 1
        }
    }

    /// Move to the previous search. Returns the text to load, or nil if already at
    /// the oldest entry.
    public mutating func undo() -> String? {
        guard position > 0 else { return nil }
        position -= 1
        return current
    }

    /// Move to the next search, or to the cleared state past the newest. Returns
    /// the text to load ("" means clear), or nil if already at the cleared end.
    public mutating func redo() -> String? {
        guard position < entries.count else { return nil }
        position += 1
        return current
    }
}
