import Foundation

/// In-memory search over one language pair's entries.
///
/// Design per the app's requirements: no database, no persisted index — a plain
/// linear scan over the entries held in RAM. Searches only run on Enter, but a
/// full dict.cc export is ~1.3M rows, so speed still matters: `String.contains`
/// is far too slow at that scale (Unicode grapheme processing per row). Instead
/// each term's case/diacritic-folded form is precomputed once at load time as a
/// UTF-8 byte array, and matching is a tight byte-level substring scan. This
/// takes real searches from ~1.7s to well under 100ms.
public final class TranslationIndex: Sendable {
    /// A row plus its folded terms (UTF-8 bytes) for matching.
    private struct Row: Sendable {
        let entry: TranslationEntry
        let left: ContiguousArray<UInt8>
        let right: ContiguousArray<UInt8>
    }

    private let rows: [Row]

    public init(entries: [TranslationEntry]) {
        self.rows = entries.map { entry in
            Row(entry: entry,
                left: Self.foldedBytes(entry.left),
                right: Self.foldedBytes(entry.right))
        }
    }

    public var count: Int { rows.count }

    /// Case- and diacritic-insensitive folding to UTF-8 bytes, so `grun` matches
    /// `grün` and `GREEN` matches `green`.
    static func foldedBytes(_ text: String) -> ContiguousArray<UInt8> {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                  locale: nil)
        return ContiguousArray(folded.utf8)
    }

    /// Match rank for one term against the needle. Lower is better; nil = no
    /// match. Surfaces the most relevant hits within the row cap.
    private enum Rank {
        static let exact = 0
        static let prefix = 1
        static let contains = 2
    }

    /// Search both languages for `query`, returning at most `limit` entries, best
    /// matches first. An entry matches if *either* side matches (dict.cc
    /// behaviour). Empty / whitespace-only queries return nothing.
    public func search(_ query: String, limit: Int) -> [TranslationEntry] {
        let needle = Self.foldedBytes(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return [] }

        var matches: [(rank: Int, order: Int, entry: TranslationEntry)] = []
        needle.withUnsafeBufferPointer { needleBuf in
            for (order, row) in rows.enumerated() {
                let leftRank = row.left.withUnsafeBufferPointer { Self.rank(hay: $0, needle: needleBuf) }
                let rightRank = row.right.withUnsafeBufferPointer { Self.rank(hay: $0, needle: needleBuf) }
                let best: Int?
                switch (leftRank, rightRank) {
                case let (l?, r?): best = min(l, r)
                case let (l?, nil): best = l
                case let (nil, r?): best = r
                default: best = nil
                }
                if let best { matches.append((best, order, row.entry)) }
            }
        }

        // Sort by rank, then original file order for stability.
        matches.sort { lhs, rhs in
            lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.order < rhs.order
        }

        return matches.prefix(limit).map(\.entry)
    }

    /// Byte-level rank of `needle` within `hay`.
    private static func rank(hay: UnsafeBufferPointer<UInt8>, needle: UnsafeBufferPointer<UInt8>) -> Int? {
        let h = hay.count, n = needle.count
        if n > h { return nil }

        // Exact.
        if h == n {
            var i = 0
            while i < n { if hay[i] != needle[i] { break }; i += 1 }
            if i == n { return Rank.exact }
        }

        // Prefix.
        var isPrefix = true
        var i = 0
        while i < n { if hay[i] != needle[i] { isPrefix = false; break }; i += 1 }
        if isPrefix { return Rank.prefix }

        // Contains (naive scan; fast enough at these sizes on folded bytes).
        let first = needle[0]
        let last = h - n
        var start = 1 // 0 already ruled out by the prefix check above
        while start <= last {
            if hay[start] == first {
                var j = 1
                while j < n && hay[start + j] == needle[j] { j += 1 }
                if j == n { return Rank.contains }
            }
            start += 1
        }
        return nil
    }
}
