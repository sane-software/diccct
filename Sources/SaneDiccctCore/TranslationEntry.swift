import Foundation

/// A single dict.cc translation row, already arranged for display: `left` is the
/// left-column language, `right` the right-column language (per the pair's
/// display rule — German on the right when present).
///
/// `wordType` (e.g. "noun", "verb") and `subject` tags (e.g. "[biochem.]") are
/// kept separately so the UI can render them subtly, the way dict.cc does. Both
/// may be empty.
public struct TranslationEntry: Hashable, Sendable, Identifiable {
    public let id: Int
    public let left: String
    public let right: String
    public let wordType: String
    public let subject: String

    public init(id: Int, left: String, right: String, wordType: String = "", subject: String = "") {
        self.id = id
        self.left = left
        self.right = right
        self.wordType = wordType
        self.subject = subject
    }
}
