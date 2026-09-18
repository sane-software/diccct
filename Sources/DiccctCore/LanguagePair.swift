import Foundation

/// A bidirectional dict.cc dataset, identified by its two language codes.
///
/// dict.cc vocabulary files are inherently bidirectional (one file matches a
/// search term in either language), so a "pair" is a single dataset, not a
/// direction. The file header (e.g. `# DE-EN vocabulary database`) fixes the
/// column order: column 0 is `code0`'s language, column 1 is `code1`'s.
///
/// Display rule (the user is German, and dict.cc is German-centric): German is
/// shown on the RIGHT, the other language on the LEFT — matching dict.cc's own
/// web layout. If a pair contains no German at all we fall back to header order.
public struct LanguagePair: Hashable, Sendable {
    /// The home language shown on the right-hand side.
    public static let homeCode = "DE"

    /// Language code of file column 0 (uppercased, e.g. "DE").
    public let code0: String
    /// Language code of file column 1 (uppercased, e.g. "EN").
    public let code1: String

    public init(code0: String, code1: String) {
        self.code0 = code0.uppercased()
        self.code1 = code1.uppercased()
    }

    /// Stable identity independent of header direction: a DE-EN and a
    /// hypothetical EN-DE file denote the same dataset. Codes are sorted so the
    /// id (and the on-disk filename derived from it) is canonical.
    public var id: String {
        [code0, code1].sorted().joined(separator: "-").lowercased()
    }

    /// Canonical filename used when importing this pair into the data directory.
    public var canonicalFileName: String { "\(id).txt" }

    /// Dropdown label, e.g. "EN<->DE". German goes on the right when present.
    public var label: String {
        if let other = otherThanHome {
            return "\(other)<->\(Self.homeCode)"
        }
        // No German in this pair: keep header order.
        return "\(code0)<->\(code1)"
    }

    /// The non-German code, if this pair contains German; otherwise nil.
    private var otherThanHome: String? {
        if code0 == Self.homeCode { return code1 }
        if code1 == Self.homeCode { return code0 }
        return nil
    }

    /// File column index whose text is displayed on the LEFT.
    public var leftColumnIndex: Int {
        // German on the right => the other language's column on the left.
        if code0 == Self.homeCode { return 1 }
        if code1 == Self.homeCode { return 0 }
        // No German: header order, column 0 on the left.
        return 0
    }

    /// File column index whose text is displayed on the RIGHT.
    public var rightColumnIndex: Int {
        leftColumnIndex == 0 ? 1 : 0
    }
}

extension LanguagePair: Comparable {
    /// Alphabetical by label — drives a deterministic dropdown order, so the
    /// "first pair wins on launch" rule is predictable across restarts.
    public static func < (lhs: LanguagePair, rhs: LanguagePair) -> Bool {
        lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
    }
}
