import Foundation

/// Parses dict.cc vocabulary files.
///
/// File shape (tab-separated), after a block of `#`-prefixed header lines:
///
///     <term col0>\t<term col1>\t<word type>\t<subject tags>
///
/// e.g. `Keratin {n}\tkeratin\tnoun\t[biochem.]`. The header carries the
/// language codes: `# DE-EN vocabulary database`.
public enum DictccParser {

    /// The dict.cc header line that names the language pair, e.g.
    /// `# DE-EN vocabulary database`.
    private static let headerRegex = try! NSRegularExpression(
        pattern: #"^#\s*([A-Za-z]{2,3})-([A-Za-z]{2,3})\s+vocabulary database"#
    )

    public enum ParseError: Error, Equatable {
        /// No `# XX-YY vocabulary database` header was found — not a dict.cc file.
        case missingHeader
        case unreadable(String)
    }

    /// Extract the language pair from a file's leading header lines without
    /// reading the whole (potentially 70+ MB) file. Reads only enough bytes to
    /// find the header.
    public static func detectPair(atPath path: String) throws -> LanguagePair {
        guard let handle = FileManager.default.contents(atPath: path) else {
            throw ParseError.unreadable(path)
        }
        // The header sits in the first few hundred bytes; sample the start.
        let sample = handle.prefix(4096)
        guard let text = String(data: sample, encoding: .utf8) else {
            throw ParseError.unreadable(path)
        }
        return try detectPair(inHeaderText: text)
    }

    /// Extract the language pair from header text (the first lines of a file).
    public static func detectPair(inHeaderText text: String) throws -> LanguagePair {
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = headerRegex.firstMatch(in: String(line), range: range),
                  let r0 = Range(match.range(at: 1), in: line),
                  let r1 = Range(match.range(at: 2), in: line) else { continue }
            return LanguagePair(code0: String(line[r0]), code1: String(line[r1]))
        }
        throw ParseError.missingHeader
    }

    /// Parse the full file at `path` into display-arranged entries for `pair`.
    /// HTML entities are decoded here so the rest of the app deals only in plain
    /// display strings.
    public static func parseEntries(atPath path: String, pair: LanguagePair) throws -> [TranslationEntry] {
        let text: String
        do {
            text = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw ParseError.unreadable(path)
        }
        return parseEntries(fromContents: text, pair: pair)
    }

    /// Parse file contents into display-arranged entries. Split out from the
    /// file-reading path so it can be exercised directly in tests.
    public static func parseEntries(fromContents text: String, pair: LanguagePair) -> [TranslationEntry] {
        let leftIndex = pair.leftColumnIndex
        let rightIndex = pair.rightColumnIndex

        var entries: [TranslationEntry] = []
        entries.reserveCapacity(1_400_000) // ~1.3M rows in a full dict.cc file

        var nextID = 0
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            // Skip header/comment lines.
            if rawLine.first == "#" { continue }

            let columns = rawLine.split(separator: "\t", omittingEmptySubsequences: false)
            // Need at least the two term columns.
            guard columns.count > max(leftIndex, rightIndex) else { continue }

            let left = HTMLEntities.decode(String(columns[leftIndex])).trimmingCharacters(in: .whitespaces)
            let right = HTMLEntities.decode(String(columns[rightIndex])).trimmingCharacters(in: .whitespaces)
            // A row with an empty term on either side is not useful.
            if left.isEmpty || right.isEmpty { continue }

            let wordType = columns.count > 2 ? String(columns[2]).trimmingCharacters(in: .whitespaces) : ""
            let subject = columns.count > 3 ? String(columns[3]).trimmingCharacters(in: .whitespaces) : ""

            entries.append(TranslationEntry(id: nextID, left: left, right: right, wordType: wordType, subject: subject))
            nextID += 1
        }
        return entries
    }
}
