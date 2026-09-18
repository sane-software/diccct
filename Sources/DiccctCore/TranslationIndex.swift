import Foundation

/// In-memory search over one language pair's entries.
///
/// Design per the app's requirements: no database, no persisted index — a plain
/// linear scan over the entries held in RAM. To keep each keystroke-free search
/// (searches only run on Enter) fast over ~1.3M rows, the case- and
/// diacritic-folded forms of every term are precomputed once at load time, so a
/// search is just substring checks, not repeated Unicode folding.
public final class TranslationIndex {
    /// A row plus its folded terms for matching.
    private struct Row {
        let entry: TranslationEntry
        let leftFolded: String
        let rightFolded: String
    }

    private let rows: [Row]

    public init(entries: [TranslationEntry]) {
        self.rows = entries.map { entry in
            Row(entry: entry,
                leftFolded: Self.fold(entry.left),
                rightFolded: Self.fold(entry.right))
        }
    }

    public var count: Int { rows.count }

    /// Case- and diacritic-insensitive folding, so `grun` matches `grün` and
    /// `STRASSE` matches `Straße`-adjacent forms as far as folding allows.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
    }

    /// Match rank for one term against the folded query. Lower is better; nil
    /// means no match. Used to surface the most relevant hits within the row cap.
    private enum Rank: Int { case exact = 0, prefix = 1, contains = 2 }

    private static func rank(term: String, query: String) -> Rank? {
        if term == query { return .exact }
        if term.hasPrefix(query) { return .prefix }
        if term.contains(query) { return .contains }
        return nil
    }

    /// Search both languages for `query`, returning at most `limit` entries,
    /// best matches first. An entry matches if *either* side matches (dict.cc
    /// behaviour). Empty / whitespace-only queries return nothing.
    public func search(_ query: String, limit: Int) -> [TranslationEntry] {
        let folded = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !folded.isEmpty else { return [] }

        // Collect (rank, originalIndex, entry) for stable ordering.
        var matches: [(rank: Int, order: Int, entry: TranslationEntry)] = []
        for (order, row) in rows.enumerated() {
            let leftRank = Self.rank(term: row.leftFolded, query: folded)
            let rightRank = Self.rank(term: row.rightFolded, query: folded)
            guard let best = [leftRank, rightRank].compactMap({ $0?.rawValue }).min() else {
                continue
            }
            matches.append((best, order, row.entry))
        }

        // Sort by rank, then by original file order for stability.
        matches.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.order < rhs.order
        }

        return matches.prefix(limit).map { $0.entry }
    }
}
